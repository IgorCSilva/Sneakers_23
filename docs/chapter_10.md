# Track Connected Carts with Presence
## Plan Your Admin Dashboard
### Turn Requirements into a Plan

Our admin dashboard needs a higher level of restriction, so we will create a dedicated Socket for it.
The Admin.DashboardController is in charge of authentication and Phoenix.Token creation. The Admin.Socket only allows admins to connect, so we do not need to add topic authorization to the Admin.DashboardChannel.

Each ShoppingCartChannel will track itself in the CartTracker when the Channel connects, and this data will be read by the Admin.DashboardChannel to build the user interface.

### Set Up Your Project
Copy the files.

- sneakers_23_admin_base/assets/css/admin.css
- sneakers_23_admin_base/assets/js/admin/dom.jss
- sneakers_23_admin_base/index.html.eex

## On Track with Phoenix Tracker
Phoenix Tracker solves the problem of tracking processes and metadata about those processes across a cluster of servers.

## Use Tracker in an Application
Go back to the HelloSocket application and start in chapter_10.md file.