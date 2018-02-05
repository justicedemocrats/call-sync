# CallSync

This web app handles:
* Fetching question and response ids, activist codes, and status codes to be
  used in our configuration system. This is done through the /configure/:candidate
  endpoint.

* Validating a particular configuration and ensuring that all questions to be
  responded to exist and have the indicated responses. This is done through the
  /validate/:candidate endpoint.

* Executing the configured sync on yesterday's calls, and writing the data to VAN
  or a CSV. This will include other systems as (this project)[https://github.com/justicedemocrats/osdi-proxy]
  advances.

## Call States

When everything is going well, calls can be:
* `unsynced`. This is either because the script has not yet run for the day or
  the call occurred before we started syncing.

* `in progress`. This means the call has been read from Mongo, and is currently
  being configured to be posted to VAN (or another system).

* `finished`. This means the call has been successfully written to VAN or a CSV.
  The call's document will have a receipt of its sync, either a VAN canvass response
  identifier or the CSVs url on S3.

* `ignored`. This means the call is of a result type that we do not want to sync,
  most likely dropped calls.

* `queued for csv`. This means that the call is of a result type that we want to pay attention
  to but that we do not want to sync to the voter file due to VAN's pricing policy
  of 1¢/req above 1k reqs/day. These calls will be exported as a CSV if the
  candidate is configured to use the money-saving half-sync strategy.

If things went wrong, there are two places it could have happened:
* We could have sent invalid data to VAN
* We could have not been able to configure the post body correctly, likely due
  to misconfigured Livevox data.

## Running

This app requires a particularly configured Airtable sheet, MongoDB, API Access
to Livevox, and an S3 bucket. If you're trying to get it set up, you should
probably just talk to Ben!
