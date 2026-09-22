# RBAC best practices for AAP

Guidance for the common case where **some people write playbooks and others run
them**. In Ansible Automation Platform (AAP), you separate these audiences with
role-based access control (RBAC) so that authors can build automation and
operators can run it — without giving operators the ability to change it.

All statements below are drawn from the AAP 2.7 product documentation; see
[References](#references).

## Core model

RBAC restricts what a user can do based on the **roles** assigned to them, either
directly or inherited through a **team**. Four building blocks:

- **Organization** — groups resources (projects, inventories, job templates,
  credentials). Assigning a user or team to an organization grants access to its
  resources.
- **Team** — a subdivision of an organization used to **bulk-assign** roles to
  many users at once. A team belongs to exactly one organization; an organization
  can have many teams.
- **Role** — a reusable collection of permissions scoped to a resource type
  (for example, read / change / administer / execute). Roles are either
  **predefined** (default, not editable) or **custom** (created for your needs).
- **User type** — `Normal` (access only to resources they are granted),
  `Administrator`/Superuser (full read-write over the whole install), and
  `Auditor` (read-only over everything).

## Best practices

1. **Apply least privilege.** Grant only the access a person needs for their
   tasks. Reserve the Administrator (Superuser) type for the few who manage the
   platform; use Auditor for read-only oversight.
2. **Separate "write" from "run".** Give operators only **Execute** on the job
   templates they must run — this lets them launch automation without being able
   to edit it. Give authors change/admin access on Projects and job templates.
   > A user can run a workflow that includes job templates they do not have
   > permission to edit; you only need **Execute** on a job template to add it to
   > a workflow.
3. **Assign roles to teams, not individuals.** Grant resource access to a team so
   every member inherits it. This scales, keeps assignments consistent, and
   removing a user from the team revokes all of that team's roles from them.
4. **Group resources with organizations.** Use organizations to draw the boundary
   around each group's projects, inventories, and templates. Note: adding a user
   to a team does **not** add them to that team's organization — assign
   organization membership separately when org-level access is required.
5. **Prefer custom roles over stacking many roles.** If predefined roles do not
   fit, create one custom role that consolidates the needed permissions, rather
   than assigning several roles per user or team.
6. **Manage users, teams, and roles in the Unified UI / platform gateway API.**
   Using the legacy automation controller API can delay propagation to
   Event-Driven Ansible by up to 15 minutes and cause auth errors for new users.
7. **Do not delete the default system administrator user.** The containerized
   installer uses it to register services; deleting it breaks install/upgrade.

## Worked example: authors vs. operators

Two teams in the same organization (for example, `Networking`):

| Team | Members | Resource | Role | Result |
| --- | --- | --- | --- | --- |
| `net-authors` | Playbook writers | Project `net-playbooks` | Admin (change) | Can sync SCM, create/edit job templates |
| `net-authors` | Playbook writers | Job templates | Admin | Can build and modify templates |
| `net-operators` | Playbook users | Job templates | **Execute** | Can launch runs; **cannot** edit templates or projects |

Setup outline (UI: **Access Management**):

1. Create the organization and add both teams to it.
2. Add the writers to `net-authors`, the runners to `net-operators`
   (**Teams → Users**).
3. On the **project**, open **Team Access → Add roles**, select `net-authors`,
   and grant the **Admin** role (project change permission).
4. On each **job template** (or via **Teams → Roles**), grant `net-authors`
   **Admin** and `net-operators` **Execute**.
5. Keep credentials owned centrally; grant use through the team rather than to
   individuals.

Net effect: authors iterate on content; operators launch approved automation and
nothing more — the separation the customer asked for.

## References

Source pages in the Red Hat AAP 2.7 documentation:

- Manage access with role-based access control —
  <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/manage-access-with-role-based-access-control>
- RBAC security considerations (roles, resources, users; least privilege) —
  <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-con_day_two_operations>
- Role-based access controls (execute vs. admin; workflows) —
  <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/develop-con_controller_role_based_access_controls>
- Bulk-assign roles to users with teams —
  <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-assembly_controller_teams>
- View, create, or assign roles to users (user types) —
  <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-assembly_controller_users>
- View, create, and assign roles (predefined vs. custom roles) —
  <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/secure-assembly_gw_roles>
- Configure project permissions —
  <https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/develop-ref_work_with_permissions>
