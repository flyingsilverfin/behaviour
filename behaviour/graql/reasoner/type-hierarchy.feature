#
# Copyright (C) 2020 Grakn Labs
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

Feature: Type Hierarchy Resolution

  Background: Set up databases for resolution testing

    Given connection has been opened
    Given connection delete all databases
    Given connection open sessions for databases:
      | materialised |
      | reasoned     |
    Given materialised database is named: materialised
    Given reasoned database is named: reasoned


  Scenario: subtypes trigger rules based on their parents; parent types don't trigger rules based on their children
    Given for each session, graql define
      """
      define

      person sub entity,
          owns name,
          plays performance:writer,
          plays performance:performer,
          plays film-production:writer,
          plays film-production:actor;

      child sub person;

      performance sub relation,
          relates writer,
          relates performer;

      film-production sub relation,
          relates writer,
          relates actor;

      name sub attribute, value string;

      performance-to-film-production sub rule,
      when {
          $x isa child;
          $y isa person;
          (performer:$x, writer:$y) isa performance;
      },
      then {
          (actor:$x, writer:$y) isa film-production;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa child, has name "a";
      $y isa person, has name "b";
      $z isa person, has name "a";
      $w isa person, has name "b2";
      $v isa child, has name "a";

      (performer:$x, writer:$z) isa performance;  # child - person   -> satisfies rule
      (performer:$y, writer:$z) isa performance;  # person - person  -> doesn't satisfy rule
      (performer:$x, writer:$v) isa performance;  # child - child    -> satisfies rule
      (performer:$y, writer:$v) isa performance;  # person - child   -> doesn't satisfy rule
      """
    When materialised database is completed
    Then for graql query
      """
      match
        $x isa person;
        $y isa person;
        (actor: $x, writer: $y) isa film-production;
      get;
      """
    Then all answers are correct in reasoned database
    # Answers are (actor:$x, writer:$z) and (actor:$x, writer:$v)
    Then answer size in reasoned database is: 2
    Then for graql query
      """
      match
        $x isa person;
        $y isa person;
        (actor: $x, writer: $y) isa film-production;
        $y has name 'a';
      get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 2
    Then for graql query
      """
      match
        $x isa person;
        $y isa child;
        (actor: $x, writer: $y) isa film-production;
      get;
      """
    Then all answers are correct in reasoned database
    # Answer is (actor:$x, writer:$v) ONLY
    Then answer size in reasoned database is: 1
    Then for graql query
      """
      match
        $x isa person;
        $y isa child;
        (actor: $x, writer: $y) isa film-production;
        $y has name 'a';
      get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
    Then for graql query
      """
      match
        $x isa child;
        $y isa person;
        (actor: $x, writer: $y) isa film-production;
      get;
      """
    Then all answers are correct in reasoned database
    # Answers are (actor:$x, writer:$z) and (actor:$x, writer:$v)
    Then answer size in reasoned database is: 2
    Then for graql query
      """
      match
        $x isa child;
        $y isa person;
        (actor: $x, writer: $y) isa film-production;
        $y has name 'a';
      get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 2
    Then materialised and reasoned databases are the same size


  Scenario: when matching different roles to those that are actually inferred, no answers are returned
    Given for each session, graql define
      """
      define

      person sub entity,
          plays family:child,
          plays family:parent,
          plays large-family:mother,
          plays large-family:father;

      family sub relation,
          relates child,
          relates parent;

      large-family sub family,
          relates child,
          relates mother as parent,
          relates father as parent;

      parents-are-mothers sub rule,
      when {
          (child: $x, parent: $y) isa family;
      },
      then {
          (child: $x, mother: $y) isa large-family;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa person;
      $y isa person;
      (child: $x, parent: $y) isa family;
      """
    When materialised database is completed
    # Matching a sibling of the actual role
    Then for graql query
      """
      match (child: $x, father: $y) isa large-family; get;
      """
    Then answer size in reasoned database is: 0
    # Matching two siblings when only one is present
    Then for graql query
      """
      match (mother: $x, father: $y) isa large-family; get;
      """
    Then answer size in reasoned database is: 0
    Then materialised and reasoned databases are the same size


  Scenario: when a sub-relation is inferred, it can be retrieved by matching its super-relation and sub-roles
    Given for each session, graql define
      """
      define

      person sub entity,
          plays performance:writer,
          plays performance:performer,
          plays film-production:writer,
          plays film-production:actor,
          plays scifi-production:scifi-writer,
          plays scifi-production:scifi-actor;

      performance sub relation,
          relates writer,
          relates performer;

      film-production sub relation,
          relates writer,
          relates actor;

      scifi-production sub film-production,
          relates scifi-writer as writer,
          relates scifi-actor as actor;

      performance-to-scifi sub rule,
      when {
          (writer:$x, performer:$y) isa performance;
      },
      then {
          (scifi-writer:$x, scifi-actor:$y) isa scifi-production;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa person;
      $y isa person;
      (writer:$x, performer:$y) isa performance;
      """
    When materialised database is completed
    # sub-roles, super-relation
    Then for graql query
      """
      match (scifi-writer:$x, scifi-actor:$y) isa film-production; get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
    Then materialised and reasoned databases are the same size


  Scenario: when a sub-relation is inferred, it can be retrieved by matching its sub-relation and super-roles
    Given for each session, graql define
      """
      define

      person sub entity,
          plays performance:writer,
          plays performance:performer,
          plays film-production:writer,
          plays film-production:actor,
          plays scifi-production:scifi-writer,
          plays scifi-production:scifi-actor;

      performance sub relation,
          relates writer,
          relates performer;

      film-production sub relation,
          relates writer,
          relates actor;

      scifi-production sub film-production,
          relates scifi-writer as film-writer,
          relates scifi-actor as actor;

      performance-to-scifi sub rule,
      when {
          (writer:$x, performer:$y) isa performance;
      },
      then {
          (scifi-writer:$x, scifi-actor:$y) isa scifi-production;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa person;
      $y isa person;
      (writer:$x, performer:$y) isa performance;
      """
    When materialised database is completed
    # super-roles, sub-relation
    Then for graql query
      """
      match (writer:$x, actor:$y) isa scifi-production; get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
    Then materialised and reasoned databases are the same size


  Scenario: when a sub-relation is inferred, it can be retrieved by matching its super-relation and super-roles
    Given for each session, graql define
      """
      define

      person sub entity,
          plays performance:writer,
          plays performance:performer,
          plays film-production:writer,
          plays film-production:actor,
          plays scifi-production:scifi-writer,
          plays scifi-production:scifi-actor;

      performance sub relation,
          relates writer,
          relates performer;

      film-production sub relation,
          relates writer,
          relates actor;

      scifi-production sub film-production,
          relates scifi-writer as film-writer,
          relates scifi-actor as actor;

      performance-to-scifi sub rule,
      when {
          (writer:$x, performer:$y) isa performance;
      },
      then {
          (scifi-writer:$x, scifi-actor:$y) isa scifi-production;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa person;
      $y isa person;
      (writer:$x, performer:$y) isa performance;
      """
    When materialised database is completed
    # super-roles, super-relation
    Then for graql query
      """
      match (writer:$x, actor:$y) isa film-production; get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
    Then materialised and reasoned databases are the same size


  Scenario: when a rule is recursive, its inferences respect type hierarchies
    Given for each session, graql define
      """
      define

      person sub entity,
          owns name,
          plays performance:writer,
          plays performance:performer,
          plays film-production:writer,
          plays film-production:actor;

      child sub person;

      performance sub relation,
          relates writer,
          relates performer;

      film-production sub relation,
          relates writer,
          relates actor;

      name sub attribute, value string;

      performance-to-film-production sub rule,
      when {
          $x isa child;
          $y isa person;
          (performer:$x, writer:$y) isa performance;
      },
      then {
          (actor:$x, writer:$y) isa film-production;
      };

      performance-to-performance sub rule,
      when {
          $x isa person;
          $y isa child;
          (performer:$x, writer:$y) isa performance;
      },
      then {
          (performer:$x, writer:$y) isa performance;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa child, has name "a";
      $y isa person, has name "b";
      $z isa person, has name "a";
      $w isa person, has name "b2";
      $v isa child, has name "a";

      (performer:$x, writer:$z) isa performance;  # child - person   -> satisfies rule
      (performer:$y, writer:$z) isa performance;  # person - person  -> doesn't satisfy rule
      (performer:$x, writer:$v) isa performance;  # child - child    -> satisfies rule
      (performer:$y, writer:$v) isa performance;  # person - child   -> doesn't satisfy rule
      """
    When materialised database is completed
    Then for graql query
      """
      match
        $x isa person;
        $y isa person;
        (actor: $x, writer: $y) isa film-production;
      get;
      """
    Then all answers are correct in reasoned database
    # Answers are (actor:$x, writer:$z) and (actor:$x, writer:$v)
    Then answer size in reasoned database is: 2
    Then for graql query
      """
      match
        $x isa person;
        $y isa person;
        (actor: $x, writer: $y) isa film-production;
        $y has name 'a';
      get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 2
    Then for graql query
      """
      match
        $x isa person;
        $y isa child;
        (actor: $x, writer: $y) isa film-production;
      get;
      """
    Then all answers are correct in reasoned database
    # Answer is (actor:$x, writer:$v) ONLY
    Then answer size in reasoned database is: 1
    Then for graql query
      """
      match
        $x isa person;
        $y isa child;
        (actor: $x, writer: $y) isa film-production;
        $y has name 'a';
      get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
    Then for graql query
      """
      match
        $x isa child;
        $y isa person;
        (actor: $x, writer: $y) isa film-production;
      get;
      """
    Then all answers are correct in reasoned database
    # Answers are (actor:$x, writer:$z) and (actor:$x, writer:$v)
    Then answer size in reasoned database is: 2
    Then for graql query
      """
      match
        $x isa child;
        $y isa person;
        (actor: $x, writer: $y) isa film-production;
        $y has name 'a';
      get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 2
    Then materialised and reasoned databases are the same size


  Scenario: querying for a super-relation gives the same answer as querying for its inferred sub-relation
    Given for each session, graql define
      """
      define

      person sub entity,
          plays residence:home-owner,
          plays residence:resident,
          plays family-residence:parent-home-owner,
          plays family-residence:child-resident,
          plays family:parent,
          plays family:child;

      residence sub relation,
          relates home-owner,
          relates resident;

      family-residence sub residence,
          relates parent-home-owner as home-owner,
          relates child-resident as resident;

      family sub relation,
          relates parent,
          relates child;

      families-live-together sub rule,
      when {
          (parent:$x, child:$y) isa family;
      },
      then {
          (parent-home-owner:$x, child-resident:$y) isa family-residence;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa person;
      $y isa person;
      (parent:$x, child:$y) isa family;
      """
    When materialised database is completed
    Then for graql query
      """
      match
        (home-owner: $x, resident: $y) isa residence;
      get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
    Then for graql query
      """
      match
        (home-owner: $x, resident: $y) isa residence;
        (parent-home-owner: $x, child-resident: $y) isa family-residence;
      get;
      """
    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
    Then materialised and reasoned databases are the same size


  # TODO: re-enable all steps once attribute re-attachment is resolvable
  Scenario: querying for a super-entity gives the same answer as querying for its inferred sub-entity
    Given for each session, graql define
      """
      define

      person sub entity;
      drunk-person sub person;
      panda sub entity;

      pandas-are-actually-drunk-people sub rule,
      when {
          $x isa panda;
      },
      then {
          $x isa drunk-person;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa panda;
      """
#    When materialised database is completed
    Then for graql query
      """
      match
        $x isa person;
      get;
      """
#    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
    Then for graql query
      """
      match
        $x isa person;
        $x isa drunk-person;
      get;
      """
#    Then all answers are correct in reasoned database
    Then answer size in reasoned database is: 1
#    Then materialised and reasoned databases are the same size