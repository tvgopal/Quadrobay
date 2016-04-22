   /*
   REM +==========================================================================+
   REM
   REM NAME
   REM XXAV_MOVE_ORDER_STG.sql
   REM
   REM PROGRAM TYPE  -> Script to Create Table
   REM
   REM PURPOSE
   REM  The purpose of this script is to create the staging table
   REM
   REM
   REM  This script is primarily used by <<Customer>> for Shipping Customization
   REM
   REM HISTORY
   REM ===========================================================================
   REM  Date          Author                  Activity
   REM ===========================================================================
   REM 06-Aug-15      SKUMAR    Created
   REM ===========================================================================
   REM Status Used 
   REM ===========
   REM      'U' or NULL - Unvalidated
   REM      'V'         - Validated
   REM      'S1'        - Move Order Created
   REM      'S2'        - Move Order Allocated
   REM      'S'         - Move Order Transacted
   REM      'E'         - Errored due to various reasons
   REM ===========================================================================*/

CONN xxav/&&xxav_passwd@&&xxav_instance;

drop table XXAV_MOVE_ORDER_STG;

CREATE TABLE xxav_move_order_stg
(
organization_id             NUMBER          NOT NULL,
description                 VARCHAR2(100)   NOT NULL,
contract_number             VARCHAR2(150)   NOT NULL,
delivery_id                 NUMBER,
delivery_detail_id          NUMBER,
move_order_type             VARCHAR2(30)    NOT NULL,
transaction_type            VARCHAR2(30)    NOT NULL,
from_subinventory_code      VARCHAR2(30)    NOT NULL,
to_subinventory_code        VARCHAR2(30)    NOT NULL,
date_required               DATE            NOT NULL,
item                        VARCHAR2(30)    NOT NULL,
inventory_item_id           NUMBER          NOT NULL,
uom_code                    VARCHAR2(30)    NOT NULL,
quantity                    NUMBER          NOT NULL,
project_number              VARCHAR2(30)    ,
task_number                 VARCHAR2(30)    ,
source_locator              VARCHAR2(50),
source_locator_project      VARCHAR2(50),
source_locator_task         VARCHAR2(50),
destination_locator         VARCHAR2(50),
destination_locator_project VARCHAR2(50),
destination_locator_task    VARCHAR2(50),
move_order_reference        VARCHAR2(50),
request_number              VARCHAR2(50),
LINE_NUMBER                 NUMBER,
attribute1                  VARCHAR2(150 ),
attribute2                  VARCHAR2(150 ),
attribute3                  VARCHAR2(150 ),
attribute4                  VARCHAR2(150 ),
attribute5                  VARCHAR2(150 ),
attribute6                  VARCHAR2(150 ),
attribute7                  VARCHAR2(150 ),
attribute8                  VARCHAR2(150 ),
attribute9                  VARCHAR2(150 ),
attribute10                 VARCHAR2(150 ),
attribute11                 VARCHAR2(150 ),
attribute12                 VARCHAR2(150 ),
attribute13                 VARCHAR2(150 ),
attribute14                 VARCHAR2(150 ),
attribute15                 VARCHAR2(150 ),
creation_date               DATE              NOT NULL,
created_by                  NUMBER            NOT NULL,
last_update_date            DATE              NOT NULL,
last_updated_by             NUMBER            NOT NULL,
last_update_login           NUMBER,
conc_req_id                 NUMBER,
error_status                VARCHAR2(2),
error_message               VARCHAR2(3000));


DROP INDEX xxav_move_order_stg_U1;

CREATE UNIQUE INDEX xxav_move_order_stg_U1 ON xxav_move_order_stg(organization_id,delivery_id,contract_number, delivery_detail_id);

GRANT ALL ON xxav.xxav_move_order_stg TO apps WITH GRANT OPTION;

CONN apps/&&apps_passwd@&&xxav_instance;

CREATE SYNONYM  apps.xxav_move_order_stg FOR xxav.xxav_move_order_stg;

