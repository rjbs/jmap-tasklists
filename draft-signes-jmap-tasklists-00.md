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
  RFC8620:
  RFC9670:
  RFC9562:
  RFC2397:
  RFC5545:
  RFC8792:
  I-D.ietf-calext-jscalendarbis:
  I-D.ietf-calext-jscalendar-icalendar:
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

{::boilerplate bcp14-tagged}

Type signatures, examples, and property descriptions in this document follow
the conventions established in {{Section 1.1 of RFC8620}}.

## Data Types

The Id data type defined in {{Section 1.2 of RFC8620}} is used in this
document. So too are the UnsignedInt, UTCDateTime, LocalDateTime, Duration, and
TimeZoneId data types defined in Sections 1.5.3, 1.5.4, 1.5.5, 1.5.6, and 1.5.8
of {{I-D.ietf-calext-jscalendarbis}} respectively.

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

### UIDs and Task Ids {#uids-and-task-ids}

Each Task has a "uid" property ({{Section 3.1.1 of
I-D.ietf-calext-jscalendarbis}}), which is a globally unique identifier that
identifies the same task in different Accounts, or different instances of the
same recurring task within an Account.

An Account MUST NOT contain more than one Task with the same uid unless all of
the Task objects have distinct, non-null values for their "recurrenceId"
property.

Where an Account does contain multiple Task objects with the same uid, they
MUST NOT have different values for their "privacy" property (see
{{Section 3.4.3 of I-D.ietf-calext-jscalendarbis}}). See {{taskset}} for how
the server enforces this.

Each Task also has an id, which is scoped to the JMAP Account and used for
referencing it in JMAP methods. There is no necessary link between the uid and
the Task's id. Tasks with the same uid in different Accounts may have different
ids.

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
{: newline="true"}

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
{: newline="true"}

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

  If not null, the value MUST be a case-insensitive color name taken from the
  set of names defined in Section 4.3 of CSS Color Module Level 3 {{COLORS}},
  or an RGB value in hexadecimal notation, as defined in Section 4.2.1 of CSS
  Color Module Level 3.

  The color SHOULD have sufficient contrast when used as text on a white
  background, unless the user explicitly chooses otherwise. The Web Content
  Accessibility Guidelines {{WCAG}} recommend at least a 4.5:1 contrast ratio
  for readability.

sortOrder: `UnsignedInt` (default: 0)
: Defines the sort order of task lists when presented in the client's UI, so it
  is consistent between devices. The number MUST be an integer in the range
  0 <= sortOrder < 2^31.

  A task list with a lower order is to be displayed before a task list with a
  higher order in any list of task lists in the client's UI. Task lists with
  equal order should be sorted in alphabetical order by name. The sorting
  should take into account locale-specific character order convention.

isSubscribed: `Boolean`
: True if the user has indicated they wish to see this TaskList in their
  client. This SHOULD default to false for TaskLists in shared accounts the
  user has access to and true for any new TaskLists created by the user
  themself.

  If false, the task list SHOULD only be displayed when the user explicitly
  requests it or to offer it for the user to subscribe to. For example, a
  company may have a large number of shared task lists which all employees have
  permission to access, but the user would only subscribe to the ones they care
  about and want to be able to have normally accessible.

isVisible: `Boolean` (default: true)
: If true, the task list's tasks should be displayed to the user. If false, the
  user has indicated they wish to temporarily hide this task list's tasks.
  Clients MUST ignore this property if isSubscribed is false. If a task is in
  multiple task lists, it should be displayed if isVisible is true for any of
  those task lists.

isDefault: `Boolean` (server-set)
: This MUST NOT be true for more than one task list within an account, and
  SHOULD be true for one of them if the account contains any. The default task list
  should be used by clients whenever they need to choose a task list for the
  user within this account, and they do not have any other information on which
  to make a choice.

defaultAlertsWithTime: `Id[Alert]|null`
: A map of alert ids to Alert objects (see {{Section 3.5.1 of
  I-D.ietf-calext-jscalendarbis}}) to apply for tasks where "showWithoutTime"
  is false and "useDefaultAlerts" is true. Ids MUST be unique across all
  default alerts in the account, including those in other task lists; a UUID
  {{RFC9562}} is recommended. The "trigger" MUST NOT be an AbsoluteTrigger, as
  this would fire for every task at the same time and so does not make sense
  for a default alert.

  If omitted on creation, the default is server dependent. For example, servers
  may choose to always default to null, or may copy the alerts from the default
  task list.

defaultAlertsWithoutTime: `Id[Alert]|null`
: A map of alert ids to Alert objects (see {{Section 3.5.1 of
  I-D.ietf-calext-jscalendarbis}}) to apply for tasks where "showWithoutTime"
  is true (that is, tasks shown without a time of day) and "useDefaultAlerts"
  is true. Ids MUST be unique across all default alerts in the account,
  including those in other task lists; a UUID {{RFC9562}} is recommended. The
  "trigger" MUST NOT be an AbsoluteTrigger, as this would fire for every task
  at the same time and so does not make sense for a default alert.

  If omitted on creation, the default is server dependent. For example, servers
  may choose to always default to null, or may copy the alerts from the default
  task list.

timeZone: `TimeZoneId|null` (default: null)
: The time zone to use for tasks without a time zone when the server needs to
  resolve them into absolute time, e.g. for alerts. The value MUST be a time
  zone id from the IANA Time Zone Database {{IANA-TZDB}}. If null, the timeZone
  of the account's associated Principal will be used; if the account has no
  associated Principal, a server-configured default time zone is used.

shareWith: `Id[TaskListRights]|null` (default: null)
: This is a map configuring who the task list is shared with, or null if it is
  not shared with anyone. Each key in the map is the id of a Principal with
  whom the task list is shared. The value for each key is the set of access
  rights that Principal has for the task list. The account id for the
  Principals may be found in the urn:ietf:params:jmap:principals:owner
  capability of the Account to which the task list belongs.

  The Principal to which this task list belongs MUST NOT be in the map.

  The property may only be modified if the user has the mayShare right.

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
{: newline="true"}

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

  The user may also modify these properties on a per-occurrence basis for
  recurring tasks (updating the "recurrenceOverrides" property of the task to
  do so).

mayShare: `Boolean`
: The user may modify the "shareWith" property for this task list.

mayDelete: `Boolean`
: The user may delete the task list itself.
{: newline="true"}

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
: If an id is given, and all creates, updates and destroys (if any) succeed
  without error, the server will try to set this task list as the default. (For
  references to TaskList creations, this is equivalent to a creation-reference,
  so the id will be the creation id prefixed with a "#".)

  If the id is not found, or the change is not permitted by the server for
  policy reasons, it MUST be ignored and the currently default task list (if
  any) will remain as such. No error is returned to the client in this case.

  As per {{Section 5.3 of RFC8620}}, if the default is successfully changed,
  any changed objects MUST be reported in either the "created" or "updated"
  argument in the response as appropriate, with the server-set value included.
{: newline="true"}

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
{: newline="true"}

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
{: newline="true"}

Task objects stored on the server MUST NOT have a "method" property, as this
is only used when representing iTIP {{RFC5546}} scheduling messages, not tasks
in a data store. This restriction does not apply to Task objects returned by
"Task/parse" (see {{task-parse}}), which represent the contents of an iCalendar
file rather than stored tasks.

The JSCalendar "progress" and "percentComplete" properties are properties of
the task itself, not of the user viewing it. In a shared task list, a change to
either is seen by every user of the list. JSCalendar's per-participant
"progress" and "percentComplete" properties (see {{Section 3.4.6 of
I-D.ietf-calext-jscalendarbis}}) record an individual contributor's progress.

## Attachments

The Link object, as defined in {{Section 1.5.11 of
I-D.ietf-calext-jscalendarbis}}, with a "rel" property equal to "enclosure" is
used to represent attachments. Instead of mandating an "href" property, clients
may set a "blobId" property instead to reference a blob of binary data in the
account, as per {{Section 6 of RFC8620}}.

The server MUST translate this to an embedded data: URL {{RFC2397}} when
sending the task to a system that cannot access the blob. Servers that support
CalDAV access to the same data are recommended to expose these files as managed
attachments {{RFC8607}}.

## Per-user properties {#per-user}

In shared task lists, any top-level property registered in the IANA registry as
"Is Per-User" set to "Yes" in the IANA "JSCalendar Properties" registry (see
{{Section 7.4 of I-D.ietf-calext-jscalendarbis}}) MUST be
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

The data store will contain a single base task, containing a recurrence rule
and/or recurrence overrides.

The client may ask the server to expand recurrences within a specific time
range in "Task/query". This will generate synthetic ids representing individual
instances in the requested time range. The client can fetch and update the
objects using these ids and the server will make the appropriate changes to the
base task. Synthetic ids do not appear in "Task/changes" responses; only the
ids of tasks as actually stored on the server.

## Task/get {#taskget}

This is a standard "/get" method as described in {{Section 5.1 of RFC8620}},
with two extra arguments:

recurrenceOverridesBefore: `UTCDateTime|null`
: If given, only recurrence overrides with a recurrence id before this date
  (when translated into UTC) will be returned.

recurrenceOverridesAfter: `UTCDateTime|null`
: If given, only recurrence overrides with a recurrence id on or after this
  date (when translated into UTC) will be returned.
{: newline="true"}

A Task object is a JSCalendar Task object so may have arbitrary properties. If
the client makes a "Task/get" call with a null or omitted "properties"
argument, all properties that are defined on the JSCalendar Task object in the
store are returned except for "iCalendar" (see
{{I-D.ietf-calext-jscalendar-icalendar}}). In addition, the "id",
"taskListIds", and "useDefaultAlerts" properties MUST be included on each
object. The "iCalendar" property is only returned if explicitly requested.

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

## Task/set {#taskset}

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

As specified in {{uids-and-task-ids}}, all Task objects with the same uid in an
Account MUST have the same value for their "privacy" property. After applying
all the creates, updates, and destroys in the "/set" request, if the Account
would contain two or more Task objects with the same uid but different values
for their "privacy" property, the server MUST reject each create or update in
the request that affects a Task with that uid with an invalidProperties
SetError. Changes in the request to Task objects with other uids are
unaffected. Note that a client wishing to change the privacy of a task that
exists as multiple instances in the Account must therefore update every
instance in the same "/set" request.

If omitted on create, the server MUST set the following properties:

* @type MUST be set to "Task"
* version MUST be set to the JSCalendar version the task conforms to, e.g.,
  "2.0" (see {{Section 3.1.2 of I-D.ietf-calext-jscalendarbis}}).
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
property is set, or the "showWithoutTime" property is true, then at least one
of the "due" and "start" properties MUST be set. A create or update that would
leave the task in violation of this MUST be rejected with an invalidProperties
SetError.

### Patching

The JMAP "/set" method allows you to update an object by sending a patch,
rather than having to supply the whole object. When doing so, care must be
taken if updating a property of a Task where the value is itself a PatchObject,
e.g. inside "localizations" or "recurrenceOverrides". In particular, you cannot
add a property with value null to the Task using a direct patch on that
property, as this is interpreted instead as a patch to remove the property.

This is more easily understood with an example. Some of the requests below are
too wide to print, and use the single backslash line-wrapping convention of
{{RFC8792}}. Suppose you have a Task object like so:

~~~
{
  "id": "42",
  "@type": "Task",
  "title": "Water the plants",
  "start": "2026-08-03T09:00:00",
  "timeZone": "Australia/Melbourne",
  "recurrenceRule": {
    "@type": "RecurrenceRule",
    "frequency": "weekly"
  },
  "alerts": {
    "5c1b": {
      "@type": "Alert",
      "trigger": {
        "@type": "OffsetTrigger",
        "offset": "-PT30M",
        "relativeTo": "start"
      }
    },
    "9f3a": {
      "@type": "Alert",
      "action": "email",
      "trigger": {
        "@type": "OffsetTrigger",
        "offset": "PT0S",
        "relativeTo": "start"
      }
    }
  },
  "recurrenceOverrides": {
    "2026-08-31T09:00:00": {
      "title": "Water the plants (and repot the ficus)"
    }
  }
}
~~~
{: title="A Task object"}

The plants are watered weekly, and on the 31st of August there is extra work to
do, so that occurrence has an overridden title. If you also wanted to give that
one occurrence a longer estimated duration, you could update the task by just
sending a patch like so:

~~~
[[ "Task/set", {
  "accountId": "a0x9",
  "update": {
    "42": {
      "recurrenceOverrides/2026-08-31T09:00:00/\
        estimatedDuration": "PT1H"
    }
  }
}, "0" ]]
~~~
{: title="\"methodCalls\" Property of a JMAP Request. NOTE: '\' line wrapping per RFC 8792."}

This patches the "2026-08-31T09:00:00" PatchObject in recurrenceOverrides so
that it ends up like this:

~~~
"recurrenceOverrides": {
  "2026-08-31T09:00:00": {
    "title": "Water the plants (and repot the ficus)",
    "estimatedDuration": "PT1H"
  }
}
~~~
{: title="\"recurrenceOverrides\" Property in a Task Object"}

Now if you changed your mind and wanted that occurrence to go back to the
task's normal estimated duration, you would remove the patch from the overrides
like so:

~~~
[[ "Task/set", {
  "accountId": "a0x9",
  "update": {
    "42": {
      "recurrenceOverrides/2026-08-31T09:00:00/\
        estimatedDuration": null
    }
  }
}, "0" ]]
~~~
{: title="\"methodCalls\" Property of a JMAP Request. NOTE: '\' line wrapping per RFC 8792."}

However, if you instead want to suppress the email alert for that one
occurrence, you could not send this patch:

~~~
[[ "Task/set", {
  "accountId": "a0x9",
  "update": {
    "42": {
      "recurrenceOverrides/2026-08-31T09:00:00/alerts~19f3a": null
    }
  }
}, "0" ]]
~~~
{: title="\"methodCalls\" Property of a JMAP Request"}

This would mean removing the "alerts/9f3a" property at path
"recurrenceOverrides" -> "2026-08-31T09:00:00" inside the object; but this
doesn't exist. We actually want to add this property and make it map to null.
The client must instead send the full object that contains the property mapping
to null, like so:

~~~
[[ "Task/set", {
  "accountId": "a0x9",
  "update": {
    "42": {
      "recurrenceOverrides/2026-08-31T09:00:00": {
        "title": "Water the plants (and repot the ficus)",
        "alerts/9f3a": null
      }
    }
  }
}, "0" ]]
~~~
{: title="\"methodCalls\" Property of a JMAP Request"}

## Task/copy

This is a standard "/copy" method as described in {{Section 5.4 of RFC8620}}.

As specified in {{taskset}}, the "privacy" property MUST NOT be set to anything
other than "public" (the default) for tasks in a task list that does not belong
to the user. If the account being copied into does not belong to the user and
the "privacy" property of the task to be created would be anything other than
"public" (whether inherited from the task being copied or set explicitly in the
"create" patch), the server MUST reject the copy with an invalidProperties
SetError.

A user with whom a task list is shared does not have access to the full data of
a task with its "privacy" property set to "private" (see {{taskget}}), so
cannot copy such a task. If the account being copied from does not belong to
the user and the "privacy" property of the task being copied is "private", the
server MUST reject the copy with a forbidden SetError. (A task with "privacy"
set to "secret" does not exist as far as any user other than the owner of the
task list is concerned, so an attempt to copy it will be rejected with a
notFound SetError.)

## Task/query {#task-query}

This is a standard "/query" method as described in {{Section 5.5 of RFC8620}},
with two extra arguments:

expandRecurrences: `Boolean` (default: false)
: If true, the server will expand any recurring task. If true, the filter MUST
  be just a FilterCondition (not a FilterOperator) and MUST include both a
  "before" and "after" property. This ensures the server is not asked to return
  an infinite number of results.

timeZone: `TimeZoneId` (default: "Etc/UTC")
: The time zone used to resolve tasks that have no time zone of their own, and
  the "before" and "after" filter conditions, into absolute time. It applies
  to sorting as well as to filtering.

  Clients SHOULD set this to the user's current time zone. A task with no time
  zone of its own falls at a different moment for each user, and only the
  client knows which; the default of "Etc/UTC" places such a task correctly
  only for a user who is themself in UTC.
{: newline="true"}

The *start instant* of a task is its "start" property resolved to absolute time
using the task's "timeZone" property, or, if the task has no "timeZone"
property, using the time zone given as the "timeZone" argument. The *due
instant* of a task is defined in the same way from its "due" property. A task
has a start instant only if it has a "start" property, and a due instant only
if it has a "due" property.

Note that the fallback here is the "timeZone" argument, not the "timeZone"
property of the TaskList the task is in ({{tasklists}}). The TaskList property
applies where the server must resolve a task with no client to ask, such as
when firing an alert; a query is made by a client that knows where the user
currently is, so the client supplies the zone.

If expandRecurrences is true, a separate id will be returned for each instance
of a recurring task that matches the query. This synthetic id is opaque to the
client, but uniquely identifies the base task id + recurrence id within the
account, allowing the server to resolve these for "/get" and "/set" operations.
Otherwise, a single id will be returned for matching recurring tasks that
represents the entire task.

There is no necessary correspondence between the ids of different instances of
the same expanded task.

The following additional errors may be returned instead of the "Task/query"
response:

expandDurationTooLarge: The query has expandRecurrences set to true, and the
duration between the "before" and "after" properties exceeds the
maxExpandedQueryDuration limit (as found in the account capabilities).

cannotCalculateOccurrences: The server cannot expand a recurrence required to
return the results for this query.

### Filtering

A *FilterCondition* object has the following properties, any of which may be
omitted:

inTaskList: `Id`
: A TaskList id. A task must be in this task list to match the condition.

after: `LocalDateTime`
: The task's due instant, or if it has none its start instant, must be on or
  after this date-time (resolved using the "timeZone" argument) to match the
  condition. A task with neither a due nor a start instant never matches this
  condition.

before: `LocalDateTime`
: The task's start instant, or if it has none its due instant, must be before
  this date-time (resolved using the "timeZone" argument) to match the
  condition. A task with neither a due nor a start instant never matches this
  condition.

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
{: newline="true"}

Note that "after" and "before" are deliberately asymmetric: together they
match tasks whose start-to-due span overlaps the window, which for a task with
only one of the two is the single date-time it does have.

If expandRecurrences is true, all conditions must match against the same
instance of a recurring task for the instance to match. If expandRecurrences is
false, all conditions must match, but they may each match any instance of the
task.

If zero properties are specified on the FilterCondition, the condition MUST
always evaluate to true. If multiple properties are specified, ALL must apply
for the condition to be true (it is equivalent to splitting the object into
one-property conditions and making them all the child of an AND filter
operator).

The exact semantics for matching String fields is *deliberately not defined* to
allow for flexibility in indexing implementation, subject to the following:

* Text should be matched in a case-insensitive manner.
* Text contained in either (but matched) single or double quotes should be
  treated as a *phrase search*, that is a match is required for that exact
  sequence of words, excluding the surrounding quotation marks. Use \", \' and
  \\ to match a literal ", ' and \ respectively in a phrase.
* Outside of a phrase, white-space should be treated as dividing separate
  tokens that may be searched for separately in the task, but must all be
  present for the task to match the filter.
* Tokens may be matched on a whole-word basis using stemming (so for example a
  text search for bus would match "buses" but not "business").

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

Sorting on "due" or "start" compares the due instants or start instants of the
tasks, as defined in {{task-query}}, rather than their local date-time values.
Two tasks due at the same moment therefore sort together even if they are in
different time zones. A task with no time zone of its own is resolved using the
"timeZone" argument, which defaults to "Etc/UTC".

Sorting on "progress" uses the task's progress as given by its "progress"
property, or as computed by the default rules in {{Section 4.2.5 of
I-D.ietf-calext-jscalendarbis}} if that property is omitted. Ascending order is
the order in which the values are listed here:

1. needs-action
2. in-process
3. completed
4. failed
5. cancelled

This puts the values a user is most likely to want to act on first. Any other
value, whether registered in the IANA "JSCalendar Enum Values" registry or
vendor-specific, sorts after all of the above; the relative order of two such
values is not defined.

The "due", "start", "priority", and "percentComplete" properties are all
optional on a Task. When sorting on one of them, tasks for which the property
is not set MUST sort after all tasks for which it is set, whether the sort is
ascending or descending. The "progress" property is always set, by the default
above, so this does not apply to it.

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

The "Task/parse" method takes the following arguments:

accountId: `Id`
: The id of the account to use.

blobIds: `Id[]`
: The ids of the blobs to parse.

properties: `String[]|null`
: If supplied, only the properties listed in the array are returned for each
  Task object. If null or omitted, defaults to all the properties.
{: newline="true"}

The response object contains the following arguments:

accountId: `Id`
: The id of the account used for the call.

parsed: `Id[Task[]]|null`
: A map of blob ids to parsed Task object representations for each successfully
  parsed blob, or null if none.

notFound: `Id[]|null`
: A list of blob ids given that could not be found, or null if none.

notParsable: `Id[]|null`
: A list of blob ids given that corresponded to blobs that could not be parsed
  as Tasks, or null if none.
{: newline="true"}

Parsed iCalendars are to be converted into Task objects following the process
defined in {{I-D.ietf-calext-jscalendar-icalendar}}. In particular, if the
iCalendar file has a METHOD property, the "method" property MUST be set on each
parsed Task object.

# Alerts {#alerts}

Alerts may be specified on tasks as described in {{Section 3.5 of
I-D.ietf-calext-jscalendarbis}}.

Alerts MUST only be triggered for tasks in task lists where the user is
subscribed.

An OffsetTrigger with a "relativeTo" value of "start" (the default) is relative
to the task's "start" property; one with a value of "end" is relative to the
task's "due" property. Per {{Section 3.5.1 of I-D.ietf-calext-jscalendarbis}},
neither value may be used on a task that lacks the corresponding property. A
"Task/set" create or update that would leave a task, or any of its recurrence
overrides, with such an alert MUST be rejected with an invalidProperties
SetError. (A task with neither a "start" nor a "due" property can therefore
only have alerts with an AbsoluteTrigger.)

Servers SHOULD NOT trigger an alert for a task whose progress is "completed" or
"cancelled".

When an alert with an "email" action is triggered, the server MUST send an
email to the user to notify them of the task. The content of the email is
implementation specific. Clients MUST NOT perform an action for these alerts.

When an alert with a "display" action is triggered, clients should display an
alert in a platform-appropriate manner to the user to remind them of the task.
Clients with a full offline cache of tasks may choose to calculate when alerts
should trigger locally. Alternatively, they can subscribe to push events from
the server.

## Default alerts {#default-alerts}

If the "useDefaultAlerts" property of a task is true, the alerts are taken from
the "defaultAlertsWithTime" or "defaultAlertsWithoutTime" property of all
TaskLists (see {{tasklists}}) the task is in, rather than the "alerts" property
of the Task.

A default alert is not part of the task, so the restriction on "relativeTo" in
{{alerts}} cannot be enforced against it when the task is changed. Instead, a
default alert with an OffsetTrigger that is relative to a property the task
does not have does not apply to that task, and MUST NOT trigger for it.

When using default alerts, the "alerts" property of the task is ignored except
for the following:

* The "acknowledged" time for an alert is stored here when a default alert for
  the task is dismissed. The id of the alert MUST be the same as the id of the
  default alert in the task list. See {{acknowledging}} on acknowledging
  alerts.
* If an alert has a "relatedTo" property with a "snooze" relation to the id of
  one of the task list default alerts, it is processed as normal and not
  ignored. This is to support snoozing default alerts; see {{snoozing}}.

## Acknowledging an alert {#acknowledging}

To dismiss an alert, clients set the "acknowledged" property of the Alert
object to the current date-time. If the alert was a task list default, it may
need to be added to the task at this point in order to acknowledge it. When
other clients fetch the updated Task they SHOULD automatically dismiss or
suppress duplicate alerts (alerts with the same alert id that triggered on or
before the "acknowledged" date-time) and alerts that have been removed from the
task.

Setting the "acknowledged" property MUST NOT create a new recurrence override.
For a recurring task, the "acknowledged" property of the parent object MUST be
updated, unless the alert is already overridden in the "recurrenceOverrides"
property.

## Snoozing an alert {#snoozing}

Users may wish to dismiss an alert temporarily and have it come back after a
specific period of time. To do this, clients MUST:

1. Acknowledge the alert as described in {{acknowledging}}.
2. Add a new alert to the task that has an AbsoluteTrigger specifying the
   date-time when the alert will trigger again. Add a "relatedTo" property to
   the new alert, setting the "snooze" relation to point to the original alert.
   This MUST NOT create a new recurrence override; it is added to the same
   "alerts" property that contains the alert that was acknowledged in step 1.

When acknowledging a snoozed alert (i.e. one with a "snooze" relatedTo pointing
to the original alert), the client should delete the alert rather than setting
the "acknowledged" property.

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
{: newline="true"}

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

A TaskNotification exposes the full details of the task that changed, so MUST
only be created for users that are allowed to see those details. If the
"privacy" property of the task is "private" or "secret", either before or after
the change, the server MUST NOT create a notification for any user other than
the Principal that owns the task list, as other users do not have access to the
full details of such a task (see {{taskget}}). The Principal that owns the task
list still receives notifications for these tasks as normal.

Apart from this, the TaskNotification does not have any per-user data. A single
instance may therefore be maintained on the server for all users with whom the
task list is shared. A notification that would not be created for a particular
user, as described above, MUST be treated as not existing for that user. The
server need only keep track of which users have yet to destroy the
notification.

The server MAY limit the maximum number of notifications it will store for a
user. When the limit is reached, any new notification will cause the previously
oldest notification to be automatically deleted.

The server MAY coalesce notifications if appropriate or remove notifications
after a certain period of time or that it deems are no longer relevant.

A *TaskNotification* object has the following properties:

id: `Id` (immutable; server-set)
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
  {: newline="true"}

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
{: newline="true"}

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
{: newline="true"}

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
finished, soonest first. The sort is on "due", so the client sends the user's
current time zone, which is where any task with no time zone of its own will
be placed. It might make the following request:

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
    "sort": [{ "property": "due" }],
    "timeZone": "Australia/Melbourne"
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
        "version": "2.0",
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

There are many ways in which a user can make a request liable to cause a server
to spend an inordinate amount of processing time. Care must be taken to limit
resources allocated to any one user to ensure the system does not become
unresponsive. The following subsections list particularly hazardous areas.

### Expanding recurrences

Recurrence rules can be crafted to occur as frequently as every second. Servers
MUST be careful to not allow resources to be exhausted when expanding, and
limit the number of expansions they will create. Equally, rules can be
generated that never create any occurrences at all. Servers MUST be careful to
limit the work spent iterating in search of the next occurrence.

### Firing alerts

An alert firing for a task can cause a notification to be pushed to the user's
devices, or to send them an email. Servers MUST rate limit the number of alerts
sent for any one user. The combination of recurring tasks with multiple alerts
can in particular define unreasonably frequent alerts, leading to denial of
service for either the server processing them or the user's devices receiving
them.

Similarly, clients generating alerts from the data on device must take the same
precautions.

The "email" alert type (see {{Section 3.5.1 of
I-D.ietf-calext-jscalendarbis}}) causes an email to be sent when triggered.
Clients MUST ignore this alert type; the email is sent only by the server.
There is no mechanism in JSCalendar to specify a particular email address: the
server MUST only allow alerts to be sent to an address it has verified as
belonging to the user to avoid this being used as a spamming vector.

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

Can Reference Blobs:
: no

Can Use for State Change:
: yes

Capability:
: urn:ietf:params:jmap:tasks

Reference:
: this document

## JMAP Data Type Registration for "Task"

IANA will register "Task" in the "JMAP Data Types" registry as follows:

Type Name:
: Task

Can Reference Blobs:
: yes

Can Use for State Change:
: yes

Capability:
: urn:ietf:params:jmap:tasks

Reference:
: this document

## JMAP Data Type Registration for "TaskNotification"

IANA will register "TaskNotification" in the "JMAP Data Types" registry as
follows:

Type Name:
: TaskNotification

Can Reference Blobs:
: no

Can Use for State Change:
: yes

Capability:
: urn:ietf:params:jmap:tasks

Reference:
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
defined in {{Section 10.8 of I-D.ietf-jmap-calendars}} are also used by this
document, for "Task/query". No new registration is required.

## JSCalendar Properties Registry

The "Is Per-User" field used below is defined by {{Section 7.4 of
I-D.ietf-calext-jscalendarbis}}.

### Added Properties

IANA will add the following entries to the "JSCalendar Properties" registry.

#### taskListIds

Property Name:
: taskListIds

Property Type:
: not applicable

Property Context:
: Task

Reference or Description:
: This document, {{tasks}}

Intended Usage:
: reserved

Since Version:
: 2.0

Change Controller:
: IETF

Is Per-User:
: No

#### baseTaskId

Property Name:
: baseTaskId

Property Type:
: not applicable

Property Context:
: Task

Reference or Description:
: This document, {{tasks}}

Intended Usage:
: reserved

Since Version:
: 2.0

Change Controller:
: IETF

Is Per-User:
: No

### Updated Properties

The following property is already registered in the "JSCalendar Properties"
registry by {{I-D.ietf-calext-jscalendarbis}}. IANA will update the entry as
follows. Only the Property Name and the changed fields are listed; unchanged
fields are omitted.

#### useDefaultAlerts

Property Name:
: useDefaultAlerts

Property Context:
: Event, Task

The "id" property is registered with a Property Context of "Event, Task" by
{{Section 10.9.1.1 of I-D.ietf-jmap-calendars}}; no update is required for its
use here.

--- back

# Acknowledgments
{:numbered="false"}

This document is largely a transliteration of JMAP for Calendars
{{I-D.ietf-jmap-calendars}}, and owes everything to its authors and reviewers.
