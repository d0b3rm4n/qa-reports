#
# This file is part of meego-test-reports
#
# Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies).
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

require 'file_storage'
require 'cache_helper'
class ApiController < ApplicationController
  include CacheHelper

  cache_sweeper :meego_test_session_sweeper, :only => [:import_data]
  before_filter :api_authentication, :except => [:reports_by_limit_and_time]

  def record_not_found
    head :not_found
  end

  def import_data
    errors = []
    fix_request_params(params, errors)
    if !errors.empty?
      render :json => {:ok => '0', :errors => "Request contained invalid files: " + errors.join(',')}
      return
    end

    # Map deprecated API params to current ones
    params[:hardware] ||= params[:hwproduct]
    params[:product]  ||= params[:hardware]
    params[:testset]  ||= params[:testtype]
    params.delete(:hwproduct)
    params.delete(:testtype)
    params.delete(:hardware)
    params[:build_id] ||= params.delete(:build_id_txt) if params[:build_id_txt]

    begin
      return render :json => {:ok => '0', :errors => {:target => "can't be blank"}} if not params[:target]
      return render :json => {:ok => '0', :errors => {:target => "Incorrect target '#{params[:target]}'. Valid ones are: #{Profile.names.join(',')}."}} if not Profile.find_by_name(params[:target])
      @test_session = ReportFactory.new.build(params.clone)
      return render :json => {:ok => '0', :errors => errmsg_invalid_version(params[:release_version])} if not @test_session.release
      @test_session.author = current_user
      @test_session.editor = current_user
      @test_session.published = true

    rescue ActiveRecord::UnknownAttributeError => error
      render :json => {:ok => '0', :errors => error.message}
      return
    end

    # Check the errors
    if @test_session.errors.size > 0
      render :json => {:ok => '0', :errors => @test_session.errors}
      return
    end

    begin
      @test_session.save!

      report_url = url_for :controller => 'reports', :action => 'show', :release_version => @test_session.release.name, :target => params[:target], :testset => params[:testset], :product => params[:product], :id => @test_session.id
      render :json => {:ok => '1', :url => report_url}
    rescue ActiveRecord::RecordInvalid => invalid
      error_messages = {}
      invalid.record.errors.each do |key, value|
        # If there are more than one errors for a key return them as an array
        if invalid.record.errors[key].length > 1
          error_messages[key] ||= []
          error_messages[key] << value
        else
          error_messages[key] = value
        end
      end
      render :json => {:ok => '0', :errors => error_messages}
    end

  end

  def merge_result
    report = MeegoTestSession.find(params[:id])
    report.merge_result_files!(params[:result_files])

    if report.errors.empty? && report.save
      report.update_attribute(:editor, current_user)
      head :ok
    else
      render :json => {:errors => report.errors}, :status => :unprocessable_entity
    end
  end

  def update_result
    errors = []
    fix_request_params(params, errors)
    if !errors.empty?
      render :json => {:ok => '0', :errors => "Request contained invalid files: " + errors.join(',')}
      return
    end

    params[:updated_at] = params[:updated_at] || Time.now

    parse_err = nil

    if @report_id = params[:id].try(:to_i)
      begin
        @test_session = MeegoTestSession.find(@report_id)
        parse_err = @test_session.update_report_result(current_user, params, true)
      rescue ActiveRecord::UnknownAttributeError, ActiveRecord::RecordNotSaved => errors
        # TODO: Could we get reasonable error messages somehow? e.g. MeegoTestCase
        # may add an error from custom results but this just has a very generic error message
        render :json => {:ok => '0', :errors => errors.message}
        return
      end

      if parse_err.present?
        render :json => {:ok => '0', :errors => "Request contained invalid files: " + parse_err}
        return
      end

      if @test_session.save
        expire_caches_for(@test_session, true)
        expire_index_for(@test_session)
      else
        render :json => {:ok => '0', :errors => invalid.record.errors}
        return
      end

      render :json => {:ok => '1'}
    end
  end

  def reports_by_limit_and_time
    begin
      raise ArgumentError, "Limit not defined" if not params.has_key? :limit_amount
      sessions = MeegoTestSession.published.order("updated_at asc").limit(params[:limit_amount])
      if params.has_key? :begin_time
        begin_time = DateTime.parse params[:begin_time]
        sessions = sessions.where('updated_at > ?', begin_time)
      end
      hashed_sessions = sessions.map { |s| ReportExporter::hashify_test_session(s) }
      render :json => hashed_sessions
    rescue ArgumentError => error
      render :json => {:ok => '0', :errors => error.message}
    end
  end

  private

  ATTACHMENT_TYPE_MAPPING = {'report' => :result_file, 'attachment' => :attachment}

  def collect_file(parameters, key, errors)
    file = parameters.delete(key)
    if (file!=nil)
      if (!file.respond_to?(:path))
        errors << "Invalid file attachment for field " + key
      end
      FileAttachment.new(:file => file, :attachment_type => ATTACHMENT_TYPE_MAPPING[key.split('.').first])
    end
  end

  def collect_files(parameters, name, errors)
    results = []
    results << collect_file(parameters, name, errors)
    parameters.keys.select { |key|
      key.starts_with?(name+'.')
    }.sort.each { |key|
      results << collect_file(parameters, key, errors)
    }
    results.compact
  end

  def errmsg_invalid_version(version)
    {:release_version => "Incorrect release version '#{version}'. Valid ones are #{Release.names.join(',')}."}
  end

  def api_authentication
      return render :status => 403, :json => {:errors => "Missing authentication token."} if params[:auth_token].nil?
      return render :status => 403, :json => {:errors => "Invalid authentication token."} unless user_signed_in?
  end

  def fix_request_params(params, errors)
    # Delete params not understood by models
    params.delete(:auth_token)
    params.delete(:controller)
    params.delete(:action)

    # Fix result files and attachments.
    params[:result_files] ||= []
    params[:attachments]  ||= []

    # Convert uploaded files to FileAttachments
    params[:result_files] = params[:result_files].map do |f| FileAttachment.new(:file => f, :attachment_type => :result_file) end if params[:result_files]
    params[:attachments]  = params[:attachments].map  do |f| FileAttachment.new(:file => f, :attachment_type => :attachment)  end if params[:attachments]

    # Read files from the deprecated fields as well
    params[:result_files] += collect_files(params, "report", errors)
    params[:attachments]  += collect_files(params, "attachment", errors)

  end
end
