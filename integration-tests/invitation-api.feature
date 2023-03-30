Feature: Invitations API
  Background:
    Given a user named "Johnson" with password "testpass"
    Given a user named "Thompson" with password "testpass"
    Given a user named "EvilBob" with password "testpass"

  Scenario: Show basic invitation api in action

    #
    # Get the user and default org ids for two users...
    #
    Given I am logged in as "Johnson"
    When I GET path "/api/users/me"
    Then the response code should be 200
    Given I store the ".organizations[0]" selection from the response as ${johnson_organization_id}
    Given I store the ".id" selection from the response as ${johnson_user_id}

    Given I am logged in as "Thompson"
    When I GET path "/api/users/me"
    Then the response code should be 200
    Given I store the ".organizations[0]" selection from the response as ${thompson_organization_id}
    Given I store the ".id" selection from the response as ${thompson_user_id}

    # Current user is Thompson.. try to self add to Johnson's org.
    # this should not be allowed.
    When I POST path "/api/invitations" with json body:
      """
      {
        "user_id": "${thompson_user_id}",
        "organization_id": "${johnson_organization_id}"
      }
      """
    Then the response code should be 404
    And the response should match json:
      """
      {"error":"not found","resource":"organization"}
      """

    #
    # Verify Thompson can invite Johnson to his org:
    When I POST path "/api/invitations" with json body:
      """
      {
        "user_id": "${johnson_user_id}",
        "organization_id": "${thompson_organization_id}"
      }
      """
    Then the response code should be 201
    Given I store the ".id" selection from the response as ${invitation_id}
    And the response should match json:
      """
      {
        "expiry": "${response.expiry}",
        "id": "${invitation_id}",
        "organization_id": "${thompson_organization_id}",
        "user_id": "${johnson_user_id}"
      }
      """

    #
    # Verify Thompson and Johnson can see the invitation
    When I GET path "/api/invitations"
    Then the response code should be 200
    And the response should match json:
      """
      [
        {
          "expiry": "${response[0].expiry}",
          "id": "${invitation_id}",
          "organization_id": "${thompson_organization_id}",
          "user_id": "${johnson_user_id}"
        }
      ]
      """

    Given I am logged in as "Johnson"
    When I GET path "/api/invitations"
    Then the response code should be 200
    And the response should match json:
      """
      [
        {
          "expiry": "${response[0].expiry}",
          "id": "${invitation_id}",
          "organization_id": "${thompson_organization_id}",
          "user_id": "${johnson_user_id}"
        }
      ]
      """

    # But EvilBob should not see the invitation.
    Given I am logged in as "EvilBob"
    When I GET path "/api/invitations"
    Then the response code should be 200
    And the response should match json:
      """
      []
      """

    # Only Johnson should be able to accept the invitation.
    Given I am logged in as "EvilBob"
    When I POST path "/api/invitations/${invitation_id}/accept"
    Then the response code should be 404
    And the response should match json:
      """
      {"error":"not found","resource":"invitation"}
      """

    Given I am logged in as "Thompson"
    When I POST path "/api/invitations/${invitation_id}/accept"
    Then the response code should be 404
    And the response should match json:
      """
      {"error":"not found","resource":"invitation"}
      """

    Given I am logged in as "Johnson"
    When I POST path "/api/invitations/${invitation_id}/accept"
    Then the response code should be 204
    And the response should match ""

    # The invitation should be now deleted...
    When I GET path "/api/invitations"
    Then the response code should be 200
    And the response should match json:
      """
      []
      """

    # Johnson should be in two orgs now...
    When I GET path "/api/users/me"
    Then the response code should be 200
    And the response should match json:
      """
      {
        "devices": [],
        "id": "${johnson_user_id}",
        "invitations": [],
        "organizations": [
          "${johnson_organization_id}",
          "${thompson_organization_id}"
        ],
        "username": "${response.username}"
      }
      """