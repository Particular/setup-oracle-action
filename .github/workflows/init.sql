WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

create user particular identified by Welcome1;
create user particular2 identified by Welcome1;

grant all privileges to particular;
grant all privileges to particular2;

exit;