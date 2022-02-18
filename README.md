Redmine Tables
==================

Create tables and assign Custom Fields to its columns. If your Custom Table belongs to a Task, you may assign Custom Table Workflows to allow/disallow editing of any column.

Assign a role to your users/groups with the following permissions:

* View table rows (view and export)
* Edit table rows
* Delete table rows
* Upload CSV data as new rows
* Bulk edit

You can still create and grant those permissions to Tables that aren't related to a Project or Task. They are accessible directly, as new page.

Every row of data is searchable. Export the whole table or only the selected rows to CSV or PDF.

New data may be inserted with CSV upload.

This plugin provides a possibility to create custom tables. The table is built with Redmine custom fields. 

It allows you to create any databases you need for your business and integrate it into your workflow processesusing [Redmine Custom Workflows plugin](https://github.com/anteo/redmine_custom_workflows).


<img src="custom_tables.jpg" width="800"/>



New Features
-------------
* Upload CSV file to populate the Tables
* Minor bug fixes
* Table Workflows (allowing editing the tables's fields based on Issue Status)
* Tables may not be related to an Issue
* Tables can be viewed, edited, searched, exported to pdf/csv and more by non admin users

WIP (Work in Progress)
-------------

* Pivot Table
* Table attachments
* Searching through tables has some minor bugs
* API is not fully operational or tested
* Allow a permited non admin user to create/edit/delete the definition of Tables.

Compatibility
-------------
* Redmine 4.0.0 or higher

Installation and Setup
----------------------

* Clone or [download](https://github.com/marcelbonnet/redmine_tables/archive/master.zip) this repo into your **redmine_root/plugins/** folder

```
$ git clone https://github.com/marcelbonnet/redmine_tables.git
```
* If you downloaded a tarball / zip from master branch, make sure you rename the extracted folder to `custom_tables`
* You have to run the plugin rake task to provide the assets (from the Redmine root directory):
```
$ RAILS_ENV=production bundle exec rake redmine:plugins NAME=redmine_tables
```
* Restart the web server

Usage
----------------------
1) Visit **Administration->Custom tables** to open table constructor. 
2) Press button **New table**. Fill the name field, select projects you want to enable table on and submit the form.
3) Add custom fields to your new table.
4) Grant access to the users **Administration -> Roles and permissions -> Project -> Manage custom tables**

Example Using with Redmine Custom Workflows
----------------------

* Create a new workflow
* The object you want is Custom Entity/Redmine Table

Example code to force any custom value less then 100, with CustomField ID=699, to a default value:

```
Rails.logger.info "==> TESTING 1,2,3..."

# rules
custom_field_id = 699
min = 100
default_val = 100

value = self.custom_field_value(custom_field_id)

if value.to_i < min
  self.custom_field_values = { 
    custom_field_id => default_val
  }
end
```


History
----------------------
This project was based on redmine_custom_tables from https://github.com/frywer/custom_tables and severely modified.