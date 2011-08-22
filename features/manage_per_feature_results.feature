Feature: automatically calculating the pass percentage for each features.
         and show the pass percentage in the feature summary of the report page.

  Background:
    Given I am logged in
    And the report for "results_by_feature.csv" exists on the service

  @smoke
  Scenario: Viewing the feature percentage
    Given I have created the "1.1/Core/Sanity/FeaturePassRate" report using "sim.xml"
    When I view the report "1.1/Core/Sanity/FeaturePassRate"

    Then I should see "Pass%" within "#test_results_by_feature th.th_pass_rate"
    And I should see "81%" within "#test_results_by_feature td.rate"

  Scenario: Viewing test results by feature
    Given the report for "results_by_feature.csv" exists on the service
    When I view the report "1.2/Core/automated/N900"

    Then I should see feature "Contacts" as passed
    And I should see feature "Home screen" as partially passed
    And I should see feature "Audio" as failed
    And I should see feature "Dialer" as N/A

  @selenium
  Scenario: Editing feature result comments and grading (status color)
    When I edit the report "1.2/Core/automated/N900"
    And I change comment of feature "Contacts" to "This comment is saved"
    And I change grading of feature "Contacts" to "Red"
    And I fill in comment "This comment is cancelled" for feature "Audio"
    And I cancel the comment of feature "Audio"
    And I press "Done"

    Then I should see "This comment is saved"
    And I should see feature "Contacts" as failed
    And I should not see "This comment is cancelled"
