class FeatureShow < SummaryShow

  delegate :comments, :grading, :name, :test_set_link,
           :to => :@feature

  def initialize(feature, build_diff=[])
    @feature = feature
    super(@feature, build_diff)
  end

  def history
    @build_diff.map do |report|
      feature = @feature.find_matching_feature report
      FeatureShow.new(feature) unless feature.nil?
    end
  end

  def graph_img_tag(max_cases)
    @feature.html_graph total_passed, total_failed, total_na, max_cases
  end

  def as_json(options = {})
    json = {name: name, summary: super}
    if options[:include_testcases]
      json.merge! testcases: @feature.meego_test_cases.map(&:as_json)
    end
    json
  end
end
