Redmine Custom Tables
==================

This is a fork.

This plugin provides a possibility to create custom tables. The table is built with Redmine custom fields. 

It allows you to create any databases you need for your business and integrate it into your workflow processes using [Redmine Custom Workflows plugin](https://github.com/anteo/redmine_custom_workflows).

<img src="custom_tables.jpg" width="800"/>



Old Features
-------------
* Table constructor
* API
* Integration with issues

New Features
-------------
* Upload CSV file to populate the Tables
* Minor bug fixes

WIP
-------------

* Table attachments
* Integrate with Redmine Workflows (allowing edit based on Issue's status)

Those need to be accessible to non admin users:

* Filtering 
* Sorting 
* Grouping
* History of changes
* Commenting entities
* Export CSV/PDF

Compatibility
-------------
* Redmine 4.0.0 or higher

Installation and Setup
----------------------

* Clone or [download](https://github.com/marcelbonnet/redmine_cw_custom_tables/archive/master.zip) this repo into your **redmine_root/plugins/** folder

```
$ git clone https://github.com/marcelbonnet/redmine_cw_custom_tables.git
```
* If you downloaded a tarball / zip from master branch, make sure you rename the extracted folder to `custom_tables`
* You have to run the plugin rake task to provide the assets (from the Redmine root directory):
```
$ RAILS_ENV=production bundle exec rake redmine:plugins:migrate
```
* Restart redmine

Usage
----------------------
1) Visit **Administration->Custom tables** to open table constructor. 
2) Press button **New table**. Fill the name field, select projects you want to enable table on and submit the form.
3) Add custom fields to your new table.
4) Give access to the users **Administration -> Roles and permissions -> Project -> Manage custom tables**