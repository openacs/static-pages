-- Implement OpenFTS Search service contracts
-- Dave Bauer dave@thedesignexperience.org
-- 2001-10-27

select acs_sc_impl__new(
	'FtsContentProvider',		-- impl_contract_name
	'static_page',			-- impl_name
	'static_pages'			-- impl_owner.name
);

select acs_sc_impl_alias__new(
	'FtsContentProvider',		-- impl_contract_name
	'static_page',			-- impl_name
	'datasource',			-- impl_operation_name
	'static_page__datasource',	-- impl_alias
	'TCL'				-- impl_pl
);

select acs_sc_impl_alias__new(
	'FtsContentProvider',		-- impl_contract_name
	'static_page',			-- impl_name
	'url',				-- impl_operation_name
	'static_page__url',		-- impl_alias
	'TCL'				-- impl_pl
);
