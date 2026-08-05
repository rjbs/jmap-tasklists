---
title: "JSON Meta Application Protocol (JMAP) for Task Lists"
abbrev: "JMAP Task Lists"
category: std
docname: draft-signes-jmap-tasklists-00
submissiontype: IETF
number:
date:
consensus: true
v: 3
area: ART
workgroup: JMAP
keyword:
 - tasks
 - todo
 - vtodo
venue:
  group: JSON Mail Access Protocol
  type: Working Group
  mail: jmap@ietf.org
  arch: https://mailarchive.ietf.org/arch/browse/jmap/

author:
 -
    fullname: Ricardo Signes
    organization: Fastmail
    email: rjbs@semiotic.systems

normative:
  RFC2119:
  RFC8174:
  RFC8620:
  RFC9670:
  RFC9562:
  RFC3986:
  RFC2397:
  RFC5545:
  I-D.ietf-calext-jscalendarbis:
  I-D.ietf-jmap-calendars:
  IANA-TZDB:
    target: https://www.iana.org/time-zones
    title: Time Zone Database
    author:
      org: IANA
  COLORS:
    target: https://www.w3.org/TR/css-color-3/
    title: CSS Color Module Level 3
    author:
      org: W3C

informative:
  RFC4791:
  RFC5546:
  RFC8607:
  RFC8984:
  I-D.ietf-calext-ical-tasks:
  WCAG:
    target: https://www.w3.org/TR/WCAG21/
    title: Web Content Accessibility Guidelines
    author:
      org: W3C

--- abstract

This document specifies a data model for synchronizing task data with a server
using JMAP. Clients can use this to efficiently read, write, and share task
lists, receive push notifications for changes or task reminders, and keep track
of changes made by others in a multi-user environment.

--- middle

# Introduction

JMAP ({{RFC8620}} — JSON Meta Application Protocol) is a generic protocol for
synchronizing data, such as mail, calendars or contacts, between a client and a
server. It is optimized for mobile and web environments, and aims to provide a
consistent interface to different data types.

This specification defines a data model for synchronizing task data between a
client and a server using JMAP. The data model is designed to allow a server to
provide consistent access to the same data via CalDAV {{RFC4791}} as well as
JMAP, however the functionality offered over the two protocols may differ.

This document deliberately mirrors JMAP for Calendars
{{I-D.ietf-jmap-calendars}} wherever the two data types behave alike. A client
that already implements JMAP for Calendars should find almost nothing new here
beyond the properties that JSCalendar itself defines differently for a Task
than for an Event.

Two features of JMAP for Calendars are deliberately *not* carried over:

* This document does not define scheduling. Tasks are JSCalendar objects and so
  may carry a "participants" property, but no iTIP {{RFC5546}} messages are
  sent or received on their behalf, and no participant identities are defined.
  Task assignment may be specified in a future extension.

* Tasks do not contribute to a Principal's availability, and this document
  defines no equivalent of the "Principal/getAvailability" method.

## Notational Conventions

**COPY**: Copy from JMAP for Calendars §1.1, unchanged.

## Data Types

**COPY**: Copy from JMAP for Calendars §1.2, unchanged.

## Terminology

The same terminology is used in this document as in the core JMAP
specification, see {{Section 1.6 of RFC8620}}.

The terms TaskList, Task, and TaskNotification (with these specific
capitalizations) are used to refer to the data types defined in this document
and instances of those data types.

## Data Model Overview

An Account (see {{Section 1.6.2 of RFC8620}}) with support for the task data
model contains zero or more TaskList objects, which is a named collection of
Tasks. Task lists can also provide defaults, such as alerts and a color to
apply to tasks in the list. Clients commonly let users toggle visibility of
tasks belonging to a particular task list on/off. Servers may allow a task to
belong to multiple TaskLists within an account.

A Task is a representation of a task, or recurring series of tasks, in
JSCalendar Task {{I-D.ietf-calext-jscalendarbis}} format.

TaskNotification objects keep track of the history of changes made to a task
list by other users, allowing clients to notify the user of changes to their
tasks.

In servers with support for JMAP Sharing {{RFC9670}}, data may be shared with
other users. Sharing permissions are managed per task list.

Users can normally subscribe to any task list to which they have access. This
indicates the user wants this task list to appear in their regular list of task
lists. The separate "isVisible" property stores whether the user would
currently like to view the tasks in a subscribed task list.

### UIDs and Task Ids

**COPY**: Copy from JMAP for Calendars §1.4.1, replacing CalendarEvent with
Task throughout.

## Addition to the Capabilities Object

The capabilities object is returned as part of the JMAP Session object; see
{{Section 2 of RFC8620}}. This document defines two additional capability URIs.

### urn:ietf:params:jmap:tasks {#capability-tasks}

This represents support for the TaskList, Task, and TaskNotification data types
and associated API methods, except for "Task/parse". The value of this property
in the JMAP Session "capabilities" property is an empty object.

The value of this property in an account's "accountCapabilities" property is an
object that MUST contain the following information on server capabilities and
permissions for that account:

maxTaskListsPerTask: `UnsignedInt|null`
: The maximum number of TaskLists (see {{tasklists}}) that can be assigned to a
  single Task object (see {{tasks}}). This MUST be an integer >= 1, or null for
  no limit (or rather, the limit is always the number of TaskLists in the
  account).

minDateTime: `UTCDateTime`
: The earliest date-time value the server is willing to accept for any date
  stored in a Task.

maxDateTime: `UTCDateTime`
: The latest date-time value the server is willing to accept for any date
  stored in a Task.

maxExpandedQueryDuration: `Duration`
: The maximum duration the user may query over when asking the server to expand
  recurrences.

mayCreateTaskList: `Boolean`
: If true, the user may create a task list in this account.

### urn:ietf:params:jmap:tasks:parse {#capability-tasks-parse}

This represents support for the "Task/parse" method (see {{task-parse}}). The
value of this property is an empty object in both the JMAP Session
"capabilities" property and an account's "accountCapabilities" property.

# Principals and Sharing

For systems that also support JMAP Sharing {{RFC9670}}, the
urn:ietf:params:jmap:tasks capability is used to indicate that this Principal
may be used with tasks.

## Principal Capability urn:ietf:params:jmap:tasks

A "urn:ietf:params:jmap:tasks" property is added to the Principal
"capabilities" object, the value of which is an object with the following
properties:

accountId: `Id|null`
: Id of the Account with the urn:ietf:params:jmap:tasks capability that
  contains the task data for this Principal, or null if either (a) there is
  none (e.g. the Principal is a group just used for permissions management), or
  (b) the user does not have access to any data in the account. The
  corresponding Account object can be found in the Principal's "accounts"
  property, as per {{Section 2 of RFC9670}}.

mayShareWith: `Boolean`
: If true, the user may add this Principal as a task list share target (by
  adding them to the "shareWith" property of a task list, see {{tasklists}}).

# Task Lists {#tasklists}

A TaskList is a named collection of tasks. All tasks are associated with at
least one task list.

A *TaskList* object has the following properties:

id: `Id` (immutable; server-set)
: The id of the task list.

name: `String`
: The user-visible name of the task list. This MUST NOT be the empty string and
  MUST NOT be greater than 255 octets in size when encoded as UTF-8.

description: `String|null` (default: null)
: An optional longer-form description of the task list, to provide context in
  shared environments where users need more than just the name.

color: `String|null` (default: null)
: A color to be used when displaying tasks associated with the task list.
: **COPY**: Copy the two paragraphs constraining the value from JMAP for
  Calendars §4 ("color"), unchanged.

sortOrder: `UnsignedInt` (default: 0)
: **COPY**: Copy from JMAP for Calendars §4 ("sortOrder"), replacing calendar
  with task list throughout.

isSubscribed: `Boolean`
: **COPY**: Copy from JMAP for Calendars §4 ("isSubscribed"), replacing
  Calendar with TaskList throughout.

isVisible: `Boolean` (default: true)
: If true, the task list's tasks should be displayed to the user. If false, the
  user has indicated they wish to temporarily hide this task list's tasks.
  Clients MUST ignore this property if isSubscribed is false. If a task is in
  multiple task lists, it should be displayed if isVisible is true for any of
  those task lists.

isDefault: `Boolean` (server-set)
: This SHOULD be true for exactly one task list in any account, and MUST NOT be
  true for more than one task list within an account. The default task list
  should be used by clients whenever they need to choose a task list for the
  user within this account, and they do not have any other information on which
  to make a choice.

defaultAlertsWithTime: `Id[Alert]|null`
: **COPY**: Copy from JMAP for Calendars §4 ("defaultAlertsWithTime"),
  replacing event with task and calendar with task list throughout.

defaultAlertsWithoutTime: `Id[Alert]|null`
: **COPY**: Copy from JMAP for Calendars §4 ("defaultAlertsWithoutTime"),
  replacing event with task and calendar with task list throughout.

timeZone: `TimeZoneId|null` (default: null)
: The time zone to use for tasks without a time zone when the server needs to
  resolve them into absolute time, e.g. for alerts. The value MUST be a time
  zone id from the IANA Time Zone Database {{IANA-TZDB}}. If null, the timeZone
  of the account's associated Principal will be used.

shareWith: `Id[TaskListRights]|null` (default: null)
: **COPY**: Copy from JMAP for Calendars §4 ("shareWith"), replacing calendar
  with task list and CalendarRights with TaskListRights throughout.

myRights: `TaskListRights` (server-set)
: The set of access rights the user has in relation to this TaskList. If any
  task is in multiple task lists, the user has the following rights:

  * The user may fetch the task if they have the mayReadItems right on any task
    list the task is in.
  * The user may remove a task from a task list (by modifying the task's
    "taskListIds" property) if the user has the appropriate permission for that
    task list.
  * The user may make other changes to the task if they have the right to do so
    in *all* task lists to which the task belongs.

A *TaskListRights* object has the following properties:

mayReadItems: `Boolean`
: The user may fetch the tasks in this task list.

mayWrite: `Boolean`
: The user may create, modify or destroy the tasks in this task list, or move
  tasks to or from this task list. If this is true, mayUpdatePrivate MUST also
  be true.

mayUpdatePrivate: `Boolean`
: The user may modify per-user properties (see {{per-user}}) on all tasks in
  the task list, even if they would not otherwise have permission to modify
  that task. These properties MUST all be stored per-user, and changes do not
  affect any other user of the task list.
: The user may also modify these properties on a per-occurrence basis for
  recurring tasks (updating the "recurrenceOverrides" property of the task to
  do so).

mayShare: `Boolean`
: The user may modify the "shareWith" property for this task list.

mayDelete: `Boolean`
: The user may delete the task list itself.

Note that JMAP for Calendars defines two further rights, "mayWriteOwn" and
"mayRSVP", both of which depend on identifying the user among an object's
participants. As this document defines no participant identities, it defines no
equivalent rights.

## TaskList/get

This is a standard "/get" method as described in {{Section 5.1 of RFC8620}}.
The "ids" argument may be null to fetch all at once.

## TaskList/changes

This is a standard "/changes" method as described in {{Section 5.2 of
RFC8620}}.

## TaskList/set {#tasklistset}

This is a standard "/set" method as described in {{Section 5.3 of RFC8620}} but
with the following additional request arguments:

onDestroyRemoveTasks: `Boolean` (default: false)
: If false, any attempt to destroy a TaskList that still has Tasks in it will
  be rejected with a taskListHasTask SetError. If true, any Tasks that were in
  the TaskList will be removed from it, and if in no other TaskLists they will
  be destroyed. This MAY create TaskNotification objects, if deemed likely to
  be helpful to the user; in the case of a task list with a large number of
  tasks, the server MAY choose to omit creating them. In systems supporting
  JMAP Sharing, a single ShareNotification (as defined in {{Section 3 of
  RFC9670}}) MUST be created for each Principal the task list was previously
  shared with, to inform them they no longer have access to the task list.

onSuccessSetIsDefault: `Id|null`
: **COPY**: Copy from JMAP for Calendars §4.3 ("onSuccessSetIsDefault"),
  replacing calendar with task list throughout.

The "shareWith" property may only be set by users that have the mayShare right.
When modifying the "shareWith" property, the user cannot give a right to a
Principal if the Principal did not already have that right and the user making
the change also does not have that right. Any attempt to do so must be rejected
with a forbidden SetError.

Users can subscribe or unsubscribe to a task list by setting the "isSubscribed"
property. The server MAY forbid users from subscribing to certain task lists
even though they have permission to see them, rejecting the update with a
forbidden SetError.

The following properties may be set by anyone who is subscribed to the task
list and are always stored per-user:

* name
* color
* sortOrder
* isVisible
* timeZone
* defaultAlertsWithoutTime
* defaultAlertsWithTime

The "name", "color", and "timeZone" properties are initially inherited from the
owner's copy of the task list, but if set by a user with whom the task list is
shared, they then get their own copy of the property. This does not change the
value for any other users. If the value of the property in the owner's task
list changes after this, it does not overwrite any user's custom value.

The "sortOrder", "isVisible", "defaultAlertsWithTime", and
"defaultAlertsWithoutTime" properties are initially the default value for each
user with whom the task list is shared; they are not inherited from the owner.

The following extra SetError type is defined:

For "destroy":

taskListHasTask
: The TaskList has at least one Task assigned to it, and the
  "onDestroyRemoveTasks" argument was false.

# Tasks {#tasks}

A *Task* object contains information about a task, or recurring series of
tasks. It is a JSCalendar Task object, as defined in
{{I-D.ietf-calext-jscalendarbis}}, with the following additional properties:

id: `Id` (immutable; server-set)
: The id of the Task. The id uniquely identifies a JSCalendar Task with a
  particular uid and recurrenceId within a particular account.

baseTaskId: `Id|null` (immutable; server-set)
: This is only defined if the "id" property is a synthetic id, generated by the
  server to represent a particular instance of a recurring task (see
  {{task-query}}). This property gives the id of the "real" Task this was
  generated from.

taskListIds: `Id[Boolean]`
: The set of TaskList ids this task belongs to. A task MUST belong to one or
  more TaskLists at all times (until it is destroyed). The set is represented
  as an object, with each key being a TaskList id. The value for each key in
  the object MUST be true.

useDefaultAlerts: `Boolean` (optional, default: false)
: If true, use the user's default alerts and ignore the value of the alerts
  property (see {{default-alerts}}).

Task objects MUST NOT have a "method" property, as this is only used when
representing iTIP {{RFC5546}} scheduling messages, not tasks in a data store.

The JSCalendar "progress" and "percentComplete" properties are properties of
the task itself, not of the user viewing it. In a shared task list, a change to
either is seen by every user of the list. JSCalendar's per-participant
"progress" and "percentComplete" properties (see {{Section 3.4.6 of
I-D.ietf-calext-jscalendarbis}}) record an individual contributor's progress.

## Attachments

**COPY**: Copy from JMAP for Calendars §5.3, replacing event with task
throughout.

## Per-user properties {#per-user}

In shared task lists, any top-level property registered in the IANA registry as
"Is Per-User: yes" (see {{Section 10.8 of I-D.ietf-jmap-calendars}}) MUST be
stored per-user. For Tasks this includes:

* keywords
* color
* useDefaultAlerts
* alerts

If the user modifies any such properties on a per-occurrence basis for
recurring tasks then again, these MUST also be stored per-user. Sharees
initially receive the default value for each of these properties, not whatever
value another user may have set.

When writing only per-user properties, the "updated" property MUST also be
stored just for that user if set. When fetching the "updated" property, the
value to return is whichever is later of the per-user updated time or the
updated time of the base task.

## Recurring tasks

Tasks may recur, in which case they represent multiple occurrences or
instances. Per {{Section 4.2.2 of I-D.ietf-calext-jscalendarbis}}, a task with
a "recurrenceRule" or "recurrenceId" property MUST have a "start" property, so
every instance of a recurring task has a definite start.

**COPY**: Copy the remainder of JMAP for Calendars §5.5, replacing event with
task throughout, and omitting the final paragraph about being invited to
specific instances.

## Task/get

This is a standard "/get" method as described in {{Section 5.1 of RFC8620}},
with two extra arguments:

recurrenceOverridesBefore: `UTCDateTime|null`
: If given, only recurrence overrides with a recurrence id before this date
  (when translated into UTC) will be returned.

recurrenceOverridesAfter: `UTCDateTime|null`
: If given, only recurrence overrides with a recurrence id on or after this
  date (when translated into UTC) will be returned.

A Task object is a JSCalendar Task object so may have arbitrary properties. If
the client makes a "Task/get" call with a null or omitted "properties"
argument, all properties that are defined on the JSCalendar Task object in the
store are returned except for "iCalendar". In addition, the "id" and
"taskListIds" properties MUST be included on each object. The "iCalendar"
property is only returned if explicitly requested.

A requested id may represent a server-expanded single instance of a recurring
task if the client asked the server to expand recurrences in "Task/query". In
such a case, the server will resolve any overrides and set the appropriate
"start" and "recurrenceId" properties on the Task object returned to the
client. The "recurrenceRule" and "recurrenceOverrides" properties MUST be
returned as null if requested for such a task.

The "privacy" property of a JSCalendar Task object allows the Principal that
owns the task list to override how the task is exposed to those with whom the
task list is shared. If set to "private", then when another user fetches the
task the server MUST only return properties that are:

* permitted to be shared for a "private" object by {{Section 3.4.3 of
  I-D.ietf-calext-jscalendarbis}}; or
* additional Task properties not derived from the JSCalendar Task data (i.e.
  id, baseTaskId, taskListIds).

If "privacy" is set to "secret", the server MUST behave as though the task does
not exist for all users other than the Principal that owns the task list.

## Task/changes

This is a standard "/changes" method as described in {{Section 5.2 of
RFC8620}}.

Synthetic ids generated by the server expanding recurrences in "Task/query" do
not appear in "Task/changes" responses; only the ids of tasks as actually
stored on the server.

## Task/set

This is a standard "/set" method as described in {{Section 5.3 of RFC8620}}.

An id may represent a server-expanded single instance of a recurring task if
the client asked the server to expand recurrences in "Task/query". When the
synthetic id for such an instance is given, the server MUST process an update
as an update to the recurrence override for that instance on the base task, and
a destroy as removing just that instance.

Clients MUST NOT send an update/destroy to both the base task and a synthetic
instance in a single "/set" request; the result of this is undefined.

The client may send a `null` value for any optional JSCalendar Task property on
create. This MUST be treated the same as omitting the property from the
JSCalendar Task object. Note, this only applies to top-level properties of the
Task object.

Servers MUST enforce the user's permissions as returned in the "myRights"
property of the TaskList objects and reject changes with a forbidden SetError
if not allowed.

The "privacy" property of a JSCalendar Task object allows the Principal that
owns the task list to override how the task is exposed to those with whom the
task list is shared. If this is set to "private", the task may only be
destroyed or updated by the owner of the task list it is in. Any attempt by
another user to modify such a task MUST be rejected with a forbidden SetError
(even if only modifying per-user properties). If set to "secret", the server
MUST behave as though the task does not exist for all users other than the
Principal that owns the task list.

The "privacy" property MUST NOT be set to anything other than "public" (the
default) for tasks in a task list that does not belong to the user. The server
MUST reject this with an invalidProperties SetError.

If omitted on create, the server MUST set the following properties:

* @type MUST be set to "Task"
* uid MUST be set to a new globally unique identifier, such as a UUID
  {{RFC9562}}.
* created MUST be set to the current date-time.

Whenever a task is created or updated, the "updated" property MUST be set to
the current time by the server. If the client tries to set a value for this
property it is not an error, but it MUST be overridden and replaced with the
server's time. If the task is being created and the overridden "updated" time
is now earlier than a client-supplied "created" time, the "created" time MUST
also be overridden to the server's current time.

The "method" property MUST NOT be set. Any attempt to do so is rejected with a
standard invalidProperties SetError.

As per {{Section 4.2 of I-D.ietf-calext-jscalendarbis}}, if the "timeZone"
property is not set, or the "showWithoutTime" property is true, then at least
one of the "due" and "start" properties MUST be set. A create or update that
would leave the task in violation of this MUST be rejected with an
invalidProperties SetError.

### Patching

**COPY**: Copy from JMAP for Calendars §5.9.1, replacing CalendarEvent with
Task throughout. The worked example may be reused with a task in place of the
meeting.

## Task/copy

This is a standard "/copy" method as described in {{Section 5.4 of RFC8620}}.

## Task/query {#task-query}

This is a standard "/query" method as described in {{Section 5.5 of RFC8620}},
with two extra arguments:

expandRecurrences: `Boolean` (default: false)
: If true, the server will expand any recurring task. If true, the filter MUST
  be just a FilterCondition (not a FilterOperator) and MUST include both a
  "before" and "after" property. This ensures the server is not asked to return
  an infinite number of results.

timeZone: `TimeZoneId`
: The time zone for before/after filter conditions (default: "Etc/UTC")

**COPY**: Copy the remaining four paragraphs of JMAP for Calendars §5.11
(synthetic ids, and the expandDurationTooLarge and cannotCalculateOccurrences
errors), replacing event with task throughout.

### Filtering

A *FilterCondition* object has the following properties, any of which may be
omitted:

inTaskList: `Id`
: A TaskList id. A task must be in this task list to match the condition.

after: `LocalDateTime`
: The task's due date-time, or if it has no due date-time its start date-time,
  in the time zone given as the "timeZone" argument, must be on or after this
  date to match the condition. A task with neither a due nor a start date-time
  never matches this condition.

before: `LocalDateTime`
: The task's start date-time, or if it has no start date-time its due
  date-time, in the time zone given as the "timeZone" argument, must be before
  this date to match the condition. A task with neither a due nor a start
  date-time never matches this condition.

progress: `String[]`
: The progress of the task, as given by its "progress" property or as computed
  by the default rules in {{Section 4.2.5 of I-D.ietf-calext-jscalendarbis}} if
  that property is omitted, must be one of the strings in this list to match
  the condition.

text: `String`
: Looks for the text in the "title", "description", "locations" (matching
  name/description), "participants" (matching name/email) and any other textual
  properties of the task or any recurrence of the task.

title: `String`
: Looks for the text in the "title" property of the task, or the overridden
  "title" property of a recurrence.

description: `String`
: Looks for the text in the "description" property of the task, or the
  overridden "description" property of a recurrence.

uid: `String`
: The uid of the task is exactly the given string.

If expandRecurrences is true, all conditions must match against the same
instance of a recurring task for the instance to match. If expandRecurrences is
false, all conditions must match, but they may each match any instance of the
task.

**COPY**: Copy the final three paragraphs of JMAP for Calendars §5.11.1 (the
zero/multiple property rule and the text matching semantics), replacing event
with task throughout.

### Sorting

The following properties MUST be supported for sorting:

* due
* start
* uid
* recurrenceId

The following properties SHOULD be supported for sorting:

* priority
* progress
* percentComplete
* created
* updated

The "due", "start", "priority", "progress", and "percentComplete" properties
are all optional on a Task. When sorting on a property, tasks for which the
property is not set MUST sort after all tasks for which it is set, whether the
sort is ascending or descending. For the "progress" property, the default
progress computed per {{Section 4.2.5 of I-D.ietf-calext-jscalendarbis}} is
used, so it is always set.

## Task/queryChanges

This is a standard "/queryChanges" method as described in {{Section 5.6 of
RFC8620}}.

## Task/parse {#task-parse}

This method allows the client to parse blobs as iCalendar files {{RFC5545}} to
get Task objects, from the VTODO components therein. Server support for this is
optional, and indicated via the urn:ietf:params:jmap:tasks:parse capability.

The following metadata properties on the Task objects will be null if
requested:

* id
* baseTaskId
* taskListIds

**COPY**: Copy the arguments, response arguments, and closing paragraph of JMAP
for Calendars §5.13, replacing CalendarEvent with Task throughout.

# Alerts

Alerts may be specified on tasks as described in {{Section 3.5 of
I-D.ietf-calext-jscalendarbis}}.

Alerts MUST only be triggered for tasks in task lists where the user is
subscribed.

An OffsetTrigger with a "relativeTo" value of "start" is relative to the task's
"start" property; one with a value of "end" is relative to the task's "due"
property. If the task does not have the referenced property, the alert MUST NOT
trigger. (A task with neither a "start" nor a "due" property can therefore only
be alerted on by an AbsoluteTrigger.)

Servers SHOULD NOT trigger an alert for a task whose progress is "completed" or
"cancelled".

**COPY**: Copy the final two paragraphs of JMAP for Calendars §6 (email and
display actions), replacing event with task throughout.

## Default alerts {#default-alerts}

**COPY**: Copy from JMAP for Calendars §6.1, replacing event with task and
Calendar with TaskList throughout.

## Acknowledging an alert

**COPY**: Copy from JMAP for Calendars §6.2, replacing CalendarEvent with Task
throughout.

## Snoozing an alert

**COPY**: Copy from JMAP for Calendars §6.3, replacing event with task
throughout.

## Push events

Servers that support the urn:ietf:params:jmap:tasks capability MUST support
registering for the pseudo-type "TaskAlert" in push subscriptions and event
source connections, as described in {{RFC8620}}, Sections 7.2 and 7.3.

If requested, a TaskAlert notification will be pushed whenever an alert is
triggered for the user. For Event Source connections, this notification is
pushed as an event called "taskAlert".

A *TaskAlert* object has the following properties:

@type: `String`
: This MUST be the string "TaskAlert".

accountId: `Id`
: The account id for the task list in which the alert triggered.

taskId: `Id`
: The Task id for the alert that triggered. Note, for a recurring task this is
  the id of the base task, never a synthetic id for a particular instance.

uid: `String`
: The "uid" property of the Task for the alert that triggered.

recurrenceId: `LocalDateTime|null`
: The recurrenceId for the instance of the task for which this alert is being
  triggered, or null if the task is not recurring.

alertId: `String`
: The id for the alert that triggered.

# Task Notifications

The TaskNotification data type represents changes to tasks in task lists that
the user is subscribed to where the change was not explicitly made by the user
themself. TaskNotifications are only created by the server; users cannot create
them explicitly. They are stored in the same Account as the Task that was
changed.

Clients may present the list of notifications to the user and allow the user to
dismiss them. To dismiss a notification, use a standard "/set" call to destroy
it.

The server should create a TaskNotification whenever a task is added, updated
or destroyed by someone else, for example when a task is edited directly by
another user on a shared task list.

**COPY**: Copy the three paragraphs of JMAP for Calendars §7 covering per-user
data, storage limits, and coalescing, replacing CalendarEventNotification with
TaskNotification throughout.

A *TaskNotification* object has the following properties:

id: `Id`
: The id of the TaskNotification.

created: `UTCDateTime`
: The time this notification was created.

changedBy: `Person`
: Who made the change. The Person object has the following properties:

  name: `String`
  : The name of the person who made the change.

  email: `String|null`
  : The email of the person who made the change, or null if no email is
    available.

  principalId: `Id|null`
  : The id of the Principal corresponding to the person who made the change, if
    any.

type: `String`
: This MUST be one of:

  * "created"
  * "updated"
  * "destroyed"

taskId: `Id`
: The id of the Task that this notification is about.

task: `JSCalendar Task`
: The data before the change (if updated or destroyed), or the data after
  creation (if created).

taskPatch: `PatchObject` (updated only)
: A patch encoding the change between the data in the task property, and the
  data after the update.

If the change only affects a single instance of a recurring task, the server MAY
set the task and taskPatch properties for just that instance; the taskId MUST
still be for the base task.

## TaskNotification/get

This is a standard "/get" method as described in {{Section 5.1 of RFC8620}}.

## TaskNotification/changes

This is a standard "/changes" method as described in {{Section 5.2 of
RFC8620}}.

## TaskNotification/set

This is a standard "/set" method as described in {{Section 5.3 of RFC8620}}.

Only destroy is supported; any attempt to create/update MUST be rejected with a
forbidden SetError.

## TaskNotification/query

This is a standard "/query" method as described in {{Section 5.5 of RFC8620}}.

### Filtering

A *FilterCondition* object has the following properties:

after: `UTCDateTime|null`
: The creation date must be on or after this date to match the condition.

before: `UTCDateTime|null`
: The creation date must be before this date to match the condition.

type: `String`
: The "type" property must be the same to match the condition.

taskIds: `Id[]|null`
: A list of task ids. The "taskId" property of the notification must be in this
  list to match the condition.

### Sorting

The "created" property MUST be supported for sorting.

## TaskNotification/queryChanges

This is a standard "/queryChanges" method as described in {{Section 5.6 of
RFC8620}}.

# Examples

For brevity, in the following examples only the "methodCalls" property of the
Request object, and the "methodResponses" property of the Response object is
shown.

## Fetching initial data

A user has authenticated and the client has fetched the JMAP Session object. It
finds a single Account with the urn:ietf:params:jmap:tasks capability, with id
"a0x9", and wants to display all the task lists and every task that is not yet
finished. It might make the following request:

~~~
[
  ["TaskList/get", {
    "accountId": "a0x9"
  }, "0"],
  ["Task/query", {
    "accountId": "a0x9",
    "filter": {
      "progress": [ "needs-action", "in-process" ]
    },
    "sort": [{ "property": "due" }]
  }, "1"],
  ["Task/get", {
    "accountId": "a0x9",
    "#ids": {
      "resultOf": "1",
      "name": "Task/query",
      "path": "/ids"
    }
  }, "2"]
]
~~~

The server might respond with something like:

~~~
[
  ["TaskList/get", {
    "accountId": "a0x9",
    "list": [{
      "id": "062adcfa-105d-455c-bc60-6db68b69c3f3",
      "name": "Groceries",
      "sortOrder": 12,
      "isDefault": false,
      "defaultAlertsWithTime": null,
      ...
    }, {
      "id": "3ddf2ad7-0e0c-4fb5-852d-f0ff56f3c662",
      "name": "Work",
      "sortOrder": 4,
      "isDefault": true,
      "defaultAlertsWithTime": {
        "631BE24C-A3B6-11EC-BF4C-B027680D752E": {
          "@type": "Alert",
          "action": "display",
          "trigger": {
            "@type": "OffsetTrigger",
            "offset": "-PT1H",
            "relativeTo": "end"
          }
        }
      },
      ...
    }],
    "notFound": [],
    "state": "~506"
  }, "0"],
  ["Task/query", {
    "accountId": "a0x9",
    "canCalculateChanges": false,
    "position": 0,
    "queryState": "~206",
    "ids": [
      "T-01c9626e-1490-43df-a34f-457021256281",
      "T-07a2b89d-96b6-4920-982a-54fdf0a386ce",
      ...
    ]
  }, "1"],
  ["Task/get", {
    "accountId": "a0x9",
    "list": [{
      "id": "T-01c9626e-1490-43df-a34f-457021256281",
      "taskListIds": {
        "3ddf2ad7-0e0c-4fb5-852d-f0ff56f3c662": true
      },
      "title": "File expenses",
      "due": "2026-08-14T17:00:00",
      "timeZone": "Australia/Melbourne",
      "useDefaultAlerts": true,
      ...
    }, ...],
    "notFound": [],
    "state": "$$/413/206"
  }, "2"]
]
~~~

## Creating a task, then completing it

The user adds a task to the default task list:

~~~
[
  ["Task/set", {
    "accountId": "a0x9",
    "create": {
      "k1": {
        "taskListIds": {
          "3ddf2ad7-0e0c-4fb5-852d-f0ff56f3c662": true
        },
        "title": "Renew passport",
        "due": "2026-09-01T09:00:00",
        "timeZone": "Australia/Melbourne",
        "estimatedDuration": "PT2H",
        "priority": 3
      }
    }
  }, "0"]
]
~~~

The server assigns the id, uid, created and updated properties:

~~~
[
  ["Task/set", {
    "accountId": "a0x9",
    "created": {
      "k1": {
        "id": "T-2f0d0b39-a2a1-4a2f-9a7f-2f2f9d9e6c11",
        "uid": "1a2d8b23-4f52-4d1d-9c31-6a1e2c0b7f44",
        "@type": "Task",
        "created": "2026-08-05T04:11:00Z",
        "updated": "2026-08-05T04:11:00Z"
      }
    },
    "newState": "~507",
    "oldState": "~506"
  }, "0"]
]
~~~

Later, the user marks it done. Note that "percentComplete" is not implied by
"progress"; a client that displays it must set it too.

~~~
[
  ["Task/set", {
    "accountId": "a0x9",
    "update": {
      "T-2f0d0b39-a2a1-4a2f-9a7f-2f2f9d9e6c11": {
        "progress": "completed",
        "percentComplete": 100
      }
    }
  }, "0"]
]
~~~

# Security Considerations

## Privacy

Task lists record what a person intends to do, when, and often for whom; this
is private data, and much of it is sensitive by the same measure calendar data
is. Servers MUST enforce the ACLs set on task lists to ensure only authorised
data is shared. The additional restrictions specified by the "privacy" property
of a JSCalendar Task object (see {{Section 3.4.3 of
I-D.ietf-calext-jscalendarbis}}) MUST also be enforced.

## Denial-of-service

**COPY**: Copy from JMAP for Calendars §9.3, §9.3.1 (Expanding Recurrences) and
§9.3.2 (Firing alerts), replacing event with task throughout. §9.3.3 (Load
spikes) does not apply in the same way, as tasks are not concentrated on the
hour mark to the degree events are, but servers may still wish to add jitter.

## Spam

Task lists shared by an untrusted party may be used to place unwanted content
in front of a user. Servers should strip any alerts on tasks added to a user's
account by another party; the "useDefaultAlerts" property should be set instead
to apply the user's preferences.

# IANA Considerations

## JMAP Capability Registration for "tasks"

IANA will register the "tasks" JMAP Capability as follows:

Capability Name:
: urn:ietf:params:jmap:tasks

Specification document:
: this document

Intended use:
: common

Change Controller:
: IETF

Security and privacy considerations:
: this document, {{capability-tasks}}

## JMAP Capability Registration for "tasks:parse"

IANA will register the "tasks:parse" JMAP Capability as follows:

Capability Name:
: urn:ietf:params:jmap:tasks:parse

Specification document:
: this document

Intended use:
: common

Change Controller:
: IETF

Security and privacy considerations:
: this document, {{capability-tasks-parse}}

## JMAP Data Type Registration for "TaskList"

IANA will register "TaskList" in the "JMAP Data Types" registry as follows:

Type Name:
: TaskList

Can reference blobs:
: no

Can Use for State Change:
: yes

Capability:
: urn:ietf:params:jmap:tasks

Specification document:
: this document

## JMAP Data Type Registration for "Task"

IANA will register "Task" in the "JMAP Data Types" registry as follows:

Type Name:
: Task

Can reference blobs:
: yes

Can Use for State Change:
: yes

Capability:
: urn:ietf:params:jmap:tasks

Specification document:
: this document

## JMAP Data Type Registration for "TaskNotification"

IANA will register "TaskNotification" in the "JMAP Data Types" registry as
follows:

Type Name:
: TaskNotification

Can reference blobs:
: no

Can Use for State Change:
: yes

Capability:
: urn:ietf:params:jmap:tasks

Specification document:
: this document

## JMAP Error Codes Registry

The following error code is registered in the "JMAP Error Codes" registry, as
defined in {{RFC8620}}.

JMAP Error Code:
: taskListHasTask

Intended use:
: common

Change controller:
: IETF

Reference:
: This document, {{tasklistset}}

Description:
: The TaskList has at least one Task assigned to it, and the
  "onDestroyRemoveTasks" argument was false.

The "expandDurationTooLarge" and "cannotCalculateOccurrences" error codes
defined in {{Section 10.7 of I-D.ietf-jmap-calendars}} are also used by this
document, for "Task/query". No new registration is required.

## JSCalendar Property Registrations

IANA will register the following additional properties in the "JSCalendar
Properties" registry.

Property Name:
: taskListIds

Property Type:
: Not applicable

Property Context:
: Task

Intended Use:
: Reserved

Is per-user:
: no

Property Name:
: baseTaskId

Property Type:
: Not applicable

Property Context:
: Task

Intended Use:
: Reserved

Is per-user:
: no

## Update to the "useDefaultAlerts" Registration

The "useDefaultAlerts" property is registered by
{{Section 10.9.8 of I-D.ietf-jmap-calendars}} with a Property Context of
"Event". IANA will update that registration to give it a Property Context of
"Event, Task".

The "id" property is already registered with a Property Context of "Event,
Task"; no update is required for its use here.

--- back

# Acknowledgments
{:numbered="false"}

This document is largely a transliteration of JMAP for Calendars
{{I-D.ietf-jmap-calendars}}, and owes everything to its authors and reviewers.
