#
# This file is part of meego-test-reports
#
# Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies).
#
# Authors: Sami Hangaslammi <sami.hangaslammi@leonidasoy.fi>
#          Jarno Keskikangas <jarno.keskikangas@leonidasoy.fi>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# version 2.1 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA
#

require 'digest/sha1'
require 'open-uri'
require 'file_storage'
require 'report_comparison'
require 'cache_helper'
require 'iconv'
require 'net/http'
require 'net/https'
require 'report_exporter'

class ReportsController < ApplicationController
  include CacheHelper
  layout        'report'
  before_filter :authenticate_user!,         :except => [:index, :categories, :show, :print, :compare, :summary, :cumulative]
  before_filter :validate_path_params,       :only   => [:show, :print]
  cache_sweeper :meego_test_session_sweeper, :only   => [:update, :delete, :publish]

  def index
    @index_model = Index.find_by_release(release, params[:show_all])
    @show_rss = true
    respond_to do |format|
      format.html { render :layout => 'application' }
      format.json { render :json   => @index_model, :callback => params[:callback]  }
    end
  end

  def categories
    json = Index.find_by_release(release, params[:scope])
    json[:profiles].delete(nil)
    render :json => json, :callback => params[:callback]
  end

  def preview
    populate_report_fields
    populate_edit_fields
    @editing          = true
    @wizard           = true
    @no_upload_link   = true
    @report_show      = ReportShow.new(MeegoTestSession.find(params[:id]))
  end

  def publish
    report = MeegoTestSession.find(params[:id])
    report.update_attribute(:published, true)

    flash[:notice] = "Your report has been successfully published"
    redirect_to show_report_path(report.release.name, report.profile.name, report.testset, report.product, report)
  end

  def show
    populate_report_fields
    @history      = history(@report, 5)
    @build_diff   = build_diff(@report, 4)
    @report_show  = ReportShow.new(MeegoTestSession.find(params[:id]), @build_diff)

    respond_to do |format|
      format.html
      format.json { render json: @report_show.as_json(include_testcases: true), :callback => params[:callback] }
    end
  end

  def summary
    @report_show = ReportShow.new(MeegoTestSession.find(params[:id]))
    render json: @report_show, :callback => params[:callback]
  end

  def print
    populate_report_fields
    @build_diff   = []
    @email        = true
    @report_show  = ReportShow.new(MeegoTestSession.find(params[:id]))
  end

  def edit
    populate_report_fields
    populate_edit_fields
    @editing        = true
    @no_upload_link = true
    @report_show    = ReportShow.new(MeegoTestSession.find(params[:id]))
  end

  def update
    @report = MeegoTestSession.find(params[:id])
    params[:report][:release_id] = Release.find_by_name(params.delete(:release)[:name]).id if params[:release].present?
    params[:report][:profile_id] = Profile.find_by_name(params.delete(:profile)[:name]).id if params[:profile].present?
    @report.update_attributes(params[:report]) # Doesn't check for failure
    @report.update_attribute(:editor, current_user)

    #TODO: Fix templates so that normal 'head :ok' response is enough
    render :text => @report.tested_at.strftime('%d %B %Y')
  end

  def destroy
    report = MeegoTestSession.find(params[:id])

    # Destroy test case attachments to get the files deleted as well
    FileAttachment.find(:all,
                        :joins      => "INNER JOIN meego_test_cases tc ON file_attachments.attachable_id = tc.id",
                        :conditions => ["tc.meego_test_session_id=? AND file_attachments.attachable_type=?", report.id, 'MeegoTestCase']).each do |att|
      att.destroy
    end

    # Delete measurements
    MeegoMeasurement.delete_by_report_id(report.id)
    SerialMeasurement.delete_by_report_id(report.id)

    # Then we have nothing left that relates to a test case, so delete
    # the test cases from the report. With this we can skip massive
    # amounts of queries to measurement and attachment tables
    MeegoTestCase.delete_all(['meego_test_session_id=?', report.id])

    report.destroy
    redirect_to root_path
  end

  #TODO: This should be in comparison controller
  def compare
    @comparison = ReportComparison.new()
    @release_version = params[:release_version]
    @target = params[:target]
    @testset = params[:testset]
    @comparison_testset = params[:comparetype]
    @compare_cache_key = "compare_page_#{@release_version}_#{@target}_#{@testset}_#{@comparison_testset}"

    MeegoTestSession.published_hwversion_by_release_version_target_testset(@release_version, @target, @testset).each{|product|
        left  = MeegoTestSession.release(@release_version).profile(@target).testset(@testset).product(product.product).first
        right = MeegoTestSession.release(@release_version).profile(@target).testset(@comparison_testset).product(product.product).first
        @comparison.add_pair(product.product, left, right)
    }
    @groups = @comparison.groups
    render :layout => "report"
  end

  def cumulate_from_sessions(params)
    start_date = MeegoTestSession.find(params[:oldest]).tested_at
    end_date   = MeegoTestSession.find(params[:latest]).tested_at

    release_id = Release.find_by_name(params[:release_version]).id
    profile_id = Profile.find_by_name(params[:target]).id


    sessions = MeegoTestSession.where("""
        tested_at >= ? AND tested_at <= ? AND
        published = 1 AND release_id = ? AND profile_id = ? AND testset = ? AND product = ?""",
        start_date, end_date, release_id, profile_id, params[:testset], params[:product])
      .order("tested_at ASC, created_at ASC")
      .includes(:features, {:meego_test_cases => :feature})

    # Save the last feature where a particular testcase occurs
    testcase_feature = {}

    features = Set.new
    sessions.each do |session|
      features = features.merge session.features.map(&:name)
      session.meego_test_cases.each do |tc|
        testcase_feature[tc.name] = tc.feature.name
      end
    end

    testcases = Hash.new{|h,k| h[k] = Hash.new}

    sessions.each do |session|
      # Update previous result for all testcases even if they no
      # longer appear in the reports
      testcases.each do |name,tc|
        tc[:prev_result] = tc[:result] if tc[:result].present?
      end

      session.meego_test_cases.each do |tc|
        tcs = testcases[tc.name]

        # Test case status is updated based on latest status, except that N/A
        # and custom statuses do not overwrite an existing result.
        unless (tc.result == MeegoTestCase::NA || tc.result == MeegoTestCase::CUSTOM) && tcs[:result].present?
          tcs[:result] = tc.result_name
        end

        if tc.result == MeegoTestCase::PASS || tc.result == MeegoTestCase::FAIL
          tcs[:last_executed] = session.title
        end

        tcs[:comment]     = tc.comment_html
        tcs[:tc_id]       = tc.tc_id
        tcs[:last_report] = session.title
      end

      yield features, testcase_feature, session, testcases
    end
  end

  # TODO return some errors
  def cumulative
    titles    = []
    dates     = []
    summaries = []
    feature_summaries = Hash.new{|h,k| h[k] = Array.new}

    final_testcases = nil
    final_testcase_feature = nil

    cumulate_from_sessions(params) do |features, testcase_feature, session, testcases|

      summary = {'Total' => testcases.length, 'Pass' => 0, 'Fail' => 0, 'N/A' => 0, 'Measured' => 0}
      summary.default = 0

      features_summary = Hash.new{|h,k| h[k] = {'Total' => 0, 'Pass' => 0, 'Fail' => 0, 'N/A' => 0, 'Measured' => 0}; h[k].default = 0; h[k]}

      # Create the snapshots, i.e. cumulative counts until current report
      testcases.each do |name,tc|
        result = tc[:result]
        summary[result] += 1
        features_summary[testcase_feature[name]][result]  += 1
        features_summary[testcase_feature[name]]['Total'] += 1
      end

      # Create cumulative history snapshots for all features.
      features.each do |f|
        if features_summary.has_key?(f)
          feature_summaries[f] << features_summary[f]
        else
          # Create cumulative history for features that are to be found
          # from later reports as well
          feature_summaries[f] << {'Pass' => 0, 'Fail' => 0, 'N/A' => 0, 'Measured' => 0}
        end
      end

      titles    << session.title
      dates     << session.tested_at
      summaries << summary

      final_testcases = testcases
      final_testcase_feature = testcase_feature
    end

    # Cumulative summary per feature
    features = []
    feature_map = {}
    feature_summaries.each do |k,v|
      feature = {name: k, summary: v.last, testcases: []}
      feature_map[k] = feature
      features << feature
    end

    # Add test cases for each feature
    final_testcases.each do |name, tc|
      feature_map[final_testcase_feature[name]][:testcases] << {
        name: name,
        tc_id: tc[:tc_id],
        result: tc[:result],
        comment: tc[:comment],
        last_report: tc[:last_report],
        prev_result: tc[:prev_result],
        last_executed: tc[:last_executed]
      }
    end

    render json: {
      'sequences' => {
        'titles' => titles, 'dates' => dates, 'summaries' => summaries, 'features' => feature_summaries
      },
      'features' => features,
      'summary' =>  summaries.last
    }, :callback => params[:callback]
  end

  private

  def validate_path_params
    if params[:release_version]
      # Raise ActiveRecord::RecordNotFound if the report doesn't exist
      MeegoTestSession.release(release.name).profile(profile.name).testset(testset).product_is(product).find(params[:id])
    end
  end

  def populate_report_fields
    @report       = MeegoTestSession.fetch_fully(params[:id])
    @nft_trends   = NftHistory.new(@report) if @report.has_nft?
    @results_list = MeegoTestCaseHelper.possible_results
  end

  def populate_edit_fields
    @build_diff       = []
    @profiles         = Profile.names
    @release_versions = Release.in_sort_order.map { |release| release.name }
    @testsets         = MeegoTestSession.release(release.name).testsets
    @products         = MeegoTestSession.release(release.name).popular_products
    @build_ids        = MeegoTestSession.release(release.name).popular_build_ids
  end

  protected

  #TODO: These should be somewhere else..
  def history(s, cnt)
    MeegoTestSession.where("(tested_at < '#{s.tested_at}' OR tested_at = '#{s.tested_at}' AND created_at < '#{s.created_at}') AND profile_id = '#{s.profile.id}' AND testset = '#{s.testset.downcase}' AND product = '#{s.product.downcase}' AND published = 1 AND release_id = #{s.release_id}").
        order("tested_at DESC, created_at DESC").limit(cnt).
        includes([{:features => :meego_test_cases}, {:meego_test_cases => :feature}])
  end

  def build_diff(s, cnt)
    sessions = MeegoTestSession.published.profile(s.profile.name).testset(s.testset).product_is(s.product).
        where("release_id = #{s.release_id} AND build_id < '#{s.build_id}' AND build_id != ''").
        order("build_id DESC, tested_at DESC, created_at DESC")

    latest = []
    sessions.each do |session|
      latest << session if (latest.empty? or session.build_id != latest.last.build_id)
    end

    diff = MeegoTestSession.where(:id => latest).
        order("build_id DESC, tested_at DESC, created_at DESC").limit(cnt).
        includes([{:features => :meego_test_cases}, {:meego_test_cases => :feature}])
  end
end
