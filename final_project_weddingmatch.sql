create database weddingmatch 
go 
use weddingmatch
go 

-- DOWN
drop trigger if exists tr_ck_vendor_availability
drop trigger if exists tr_ck_venue_availability
drop trigger if exists tr_ck_venue_capacity

If exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
	where CONSTRAINT_NAME = 'u_budget_client_venue')
	alter table budgets drop constraint u_budget_client_venue

If exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
	where CONSTRAINT_NAME = 'fk_budgets_budget_vendor_cost')
	alter table budgets drop constraint fk_budgets_budget_vendor_cost

If exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
	where CONSTRAINT_NAME = 'fk_budgets_budget_venue_cost')
	alter table budgets drop constraint fk_budgets_budget_venue_cost

If exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
	where CONSTRAINT_NAME = 'fk_budgets_budget_payment_method')
	alter table budgets drop constraint fk_budgets_budget_payment_method

If exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
	where CONSTRAINT_NAME = 'fk_budgets_budget_payment_status')
	alter table budgets drop constraint fk_budgets_budget_payment_status

If exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
	where CONSTRAINT_NAME = 'fk_budgets_budget_client_id')
	alter table budgets drop constraint fk_budgets_budget_client_id

If exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
	where CONSTRAINT_NAME = 'fk_budgets_budget_venue_id')
	alter table budgets drop constraint fk_budgets_budget_venue_id

If exists (select * from INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
	where CONSTRAINT_NAME = 'fk_budgets_budget_vendor_id')
	alter table budgets drop constraint fk_budgets_budget_vendor_id

drop table if exists payment_status_lookup
drop table if exists payment_method_lookup
drop table if exists budgets 
drop table if exists venues
drop table if exists vendors
drop table if exists clients 
go

-- UP
create table clients (
	client_id int identity not null,
	client_first_name varchar(20) not null,
	client_last_name varchar(50) not null,
	client_zipcode int not null,
	client_city varchar(50) not null,
	client_state char(2) not null,
	client_wedding_size int not null,
	client_email varchar(50) not null,
	client_phone_number char(10) null,
	client_event_date date not null,
	client_special_request varchar(50) null,
	constraint pk_clients_client_id primary key (client_id),
	constraint u_clients_client_email unique (client_email),
	constraint ck_valid_wedding_size check (client_wedding_size > 0 and client_wedding_size < 10000) 
)
go 

create table vendors (
	vendor_id int identity not null,
	vendor_name varchar(50) not null,
	vendor_type varchar(20) not null,
	vendor_travel char(1) not null,
	vendor_zipcode int not null,
	vendor_city varchar(50) not null,
	vendor_state char(2) not null,
	vendor_cost money not null,
	vendor_availability date not null,
	vendor_phone_number char(10) null,
	vendor_email varchar(50) not null,
	constraint pk_vendors_vendor_id primary key (vendor_id), 
	constraint u_vendors_vendor_email unique (vendor_email)
)

go 

create table venues (
	venue_id int identity not null,
	venue_name varchar(50) not null,
	venue_zipcode int not null,
	venue_city varchar(50) not null,
	venue_state char(2) not null,
	venue_phone_number char(10) not null,
	venue_email varchar(50) not null,
	venue_cost money not null,
	venue_capacity int not null,
	venue_availability date null,
	constraint pk_venues_venue_id primary key (venue_id),
	constraint u_venues_venue_email unique (venue_email),
	constraint ck_valid_capacity check (venue_capacity > 0) 
)
go

create table budgets (
	budget_id int identity not null,
    budget_client_id int not null,
	budget_vendor_id int null,
	budget_venue_id int null,
	budget_cost money not null,
	budget_payment_status varchar(20)  null,
	budget_payment_method varchar(20) null,
	budget_payment_due_date date null,
	budget_venue_cost money null,
	budget_vendor_cost money null,
	constraint pk_budgets_budget_id primary key (budget_id),
	constraint ck_within_budget check (budget_cost <= budget_venue_cost + budget_vendor_cost) 
)
go 


create table payment_method_lookup (
	methods varchar(20) not null,
    constraint pk_payment_method_lookup primary key (methods)
)
go

create table payment_status_lookup (
	status varchar(20) not null,
    constraint pk_payment_status_lookup primary key (status)
)
go 

alter table budgets 
	add constraint fk_budgets_budget_client_id foreign key (budget_client_id)
	references clients (client_id) 
Go 

alter table budgets 
	add constraint fk_budgets_budget_vendor_id foreign key (budget_vendor_id)
	references vendors (vendor_id) 
Go 

alter table budgets 
	add constraint fk_budgets_budget_venue_id foreign key (budget_venue_id)
	references venues (venue_id) 
Go 

alter table budgets 
	add constraint fk_budgets_budget_payment_status foreign key (budget_payment_status)
	references payment_status_lookup (status) 
Go 

alter table budgets 
	add constraint fk_budgets_budget_payment_method foreign key (budget_payment_method)
	references payment_method_lookup (methods) 
Go 

alter table budgets
	add constraint u_budget_client_venue unique (budget_client_id, budget_venue_id)
go

create trigger tr_ck_venue_capacity
    ON budgets
    instead of INSERT, UPDATE
    AS BEGIN
    DECLARE @weddingsize INT, @venuecapacity INT

    SELECT @weddingsize = c.client_wedding_size, @venuecapacity = v.venue_capacity
    FROM inserted i
    JOIN clients c ON i.budget_client_id = c.client_id
    JOIN venues v ON i.budget_venue_id = v.venue_id

    IF @weddingsize > @venuecapacity
    BEGIN
        RAISERROR('Wedding size exceeds venue capacity', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
go 

create trigger tr_ck_venue_availability
    ON budgets
    after INSERT, UPDATE
    AS BEGIN
    DECLARE @venue_availability date, @eventdate date

    SELECT @venue_availability = v.venue_availability, @eventdate = c.client_event_date
    FROM inserted i
    JOIN clients c ON i.budget_client_id = c.client_id
    join venues v on i.budget_venue_id = v.venue_id

    IF @venue_availability >= @eventdate
    BEGIN
        RAISERROR('Invalid venue choice', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
go 

create trigger tr_ck_vendor_availability
    ON budgets
    after INSERT, UPDATE
    AS BEGIN
    DECLARE @vendor_availability date, @eventdate date

    SELECT @vendor_availability = v.vendor_availability, @eventdate = c.client_event_date
    FROM inserted i
    JOIN clients c ON i.budget_client_id = c.client_id
    join vendors v on i.budget_vendor_id = v.vendor_id

    IF @vendor_availability >= @eventdate
    BEGIN
        RAISERROR('Invalid vendor choice', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
go 

--

