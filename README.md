# email-approver

A small, self-contained **Configuration-as-Code** demo for Ansible Automation
Platform (AAP) that answers a real customer question:

>  - There's a workflow that disables a policy.
>  - User wants it to pause for a human to approve that action.
>  - The approver should be notified by email and be able to approve without logging into the AAP web UI ("the portal").
>  - User is guessing that a survey might be the mechanism to collect that approve/deny decision mid-run.

## TL;DR — what the customer actually needs

| They said | What they need |
|---|---|
| "send an email to an approver" | An **email notification** on the workflow |
| "approver doesn't want to use a portal" | The approver acts from the **email / the API**, not the AAP UI |
| "refresh a survey as part of a workflow?" | Not a survey — a **workflow Approval node** |

A **survey is the wrong tool** for the approval step. A survey only collects input
*once, at launch time*; it cannot be "refreshed" or re-prompted in the middle of a
run, and it is not a gate. The correct building block is a **workflow Approval
node**, which pauses the workflow until someone approves or denies, combined with
an **email notification** that tells the approver a decision is waiting.

Surveys still have a place here — this demo uses one at launch to capture *which*
policy to disable — but the human sign-off is the Approval node, not a survey.

## What this repo builds

Applying the code creates the following objects in the **Amaya** organization,
all as code:

1. **Project / inventory / job template** — a stand-in `Disable Policy` job
   template (uses the public `ansible-tower-samples` `hello_world.yml`; swap in
   the customer's real policy-disable playbook).
2. **Email notification template** (`Email Approver Notification`) — an SMTP
   `email` notifier pointed at the approver's mailbox.
3. **Workflow job template** (`Disable Policy with Email Approval`):
   - a **launch-time survey** asking for `policy_name`,
   - an **Approval node** (`Approve Policy Disable`, 1-hour timeout),
   - on approval → runs the `Disable Policy` job; on deny/timeout → stops,
   - the email notifier attached to the workflow's **approval** events, so the
     approver is emailed the moment a request is pending.

## Why it does it this way

- **Approval node, not survey** — the Approval node is AAP's native
  human-in-the-loop pause/gate; a survey cannot pause a running workflow. See the
  approval-node behavior below.
- **The "no portal" last mile** — an approval can be actioned entirely over the
  API, no AAP UI required:

  ```
  POST /api/controller/v2/workflow_approvals/<id>/approve/   # HTTP 204
  POST /api/controller/v2/workflow_approvals/<id>/deny/
  ```

  So the approver clicks a link (or you wire the email to a button/bot that calls
  that endpoint) and never logs into the "portal." The email notification is what
  tells them there's something to approve.
- **Everything as code** — the whole thing is reproducible via
  `infra.aap_configuration`; nothing is clicked together by hand.

## The alternative we considered — email **+ webhook** — and why we didn't use it

A tempting design is: skip the Approval node, have the workflow **email** the
approver *and* expose an inbound **webhook** the approver's reply/click hits to
"continue" the workflow. We rejected it:

- **AAP has no inbound "resume this paused run" webhook.** Controller webhooks are
  *outbound* notifications (or inbound **launch** triggers from GitHub/GitLab) —
  there is no built-in inbound webhook that resumes an already-running job at a
  specific point. You would have to build and host that glue yourself.
- **It reinvents the Approval node, worse.** The Approval node already *is* the
  pause + approve/deny gate, with a timeout, an audit trail of who approved, and
  RBAC over who's allowed to. A DIY webhook has none of that unless you rebuild
  it.
- **No native state or timeout.** A paused-on-webhook design has to persist "run
  X is waiting" somewhere and expire it itself. The Approval node handles pending
  state, the 1-hour timeout, and the timed-out/denied → *on-fail/always* paths
  for you.
- **Security surface.** An inbound webhook that can advance production automation
  is an endpoint you now own, authenticate, and defend. The approve/deny API is
  already authenticated by AAP's own tokens and RBAC.

The **webhook does have a legitimate role** — as a *notification type* (outbound)
alongside or instead of email, e.g. to post the pending approval into Slack/Teams
with approve/deny buttons that call the approval API. That's complementary to the
Approval node, not a replacement for it.

## Official Red Hat documentation

- **Workflows in automation controller** — <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/using_automation_execution/controller-workflows>
- **Workflow job templates** (Approval nodes, the workflow visualizer, who can
  approve, timeout/deny behavior) — <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/using_automation_execution/controller-workflow-job-templates>
- **Notifiers / Notifications** (Email, Webhook, Slack notification types) — <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/using_automation_execution/controller-notifications>
- **Job templates → Surveys** (surveys are launch-time input) — <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/using_automation_execution/controller-job-templates>

The Approval-node + approval-notification design is unchanged through AAP 2.7;
2.6 doc links are used here because that is the content set this was authored
against. (2.7 pages live under the same paths with `/2.7/` in the URL.)

## Layout

```
email-approver/
├── dispatch_config.yml            # entry playbook (infra.aap_configuration.dispatch)
├── cleanup.yml                    # tears the demo back down
├── vars.yml.example               # non-secret config template -> copy to vars.yml
├── vars_secrets.yml.example       # secrets template          -> copy to vars_secrets.yml
├── inventory
├── requirements.yml
└── platform_configuration/        # the objects, one file per type
    ├── projects.yml
    ├── inventories.yml
    ├── job_templates.yml
    ├── notification_templates.yml
    └── workflow_templates.yml
```

`vars.yml` and `vars_secrets.yml` are **gitignored** — they hold your AAP host,
token, SMTP login and recipient addresses. Only the `.example` templates are
committed.

## Usage

1. **Configure**

   ```bash
   cp vars.yml.example vars.yml
   cp vars_secrets.yml.example vars_secrets.yml
   # edit both: AAP host + token, SMTP relay, approver recipients
   ```

2. **Install collections**

   ```bash
   ansible-galaxy collection install -r requirements.yml -p collections/
   ```

3. **Apply**

   ```bash
   ansible-playbook dispatch_config.yml -i inventory \
     -e @vars.yml -e @vars_secrets.yml
   ```

4. **Try it**
   1. In the AAP UI, launch **Disable Policy with Email Approval**.
   2. Answer the survey (`Policy to disable`).
   3. The workflow pauses at the Approval node; the approver receives an email.
   4. Approve (UI, or `POST .../approve/`) → the `Disable Policy` job runs.
      Deny or let it time out (1h) → the workflow stops.

5. **Tear down**

   ```bash
   ansible-playbook cleanup.yml -i inventory -e @vars.yml -e @vars_secrets.yml
   ```

## Notes / caveats

- **Who can approve:** a user who can execute the workflow, an org admin or
  above, or a user granted the explicit **Approve** permission on this workflow.
- **AAP has no built-in "click-to-approve from email" button.** The API
  primitives (`approve`/`deny` endpoints, plus webhook *notifications*) are what
  you integrate against to build that experience.
- **Version:** authored against `infra.aap_configuration` 4.4.0 (AAP 2.5+ `aap_*`
  auth vars); the design holds through AAP 2.7.
- **Make it real:** swap the project `scm_url` / job template `playbook` for the
  customer's actual policy-disable content.
