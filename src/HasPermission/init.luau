--!strict

--[=[
	@class HasPermission

	Provides a way to check permissions for different users. Supports various checks, and allows for complex logic such as:
	- `"UserId:1234"`
	- `{"UserId:1234", "UserId:5678"}`
	- `{"!UserId:1234", "!UserId:5678", "RequireAll"}`
]=]

--[=[
	@within HasPermission
	@type Permission string | "RequireAll" | {Permission}
]=]
type Permission = string | "RequireAll" | { Permission }

local StringChecks: {
	[string]: (Player, { string }) -> boolean,
} = {
	UserId = require(script.UserId),
}

--[=[
	Checks a table of permissions. If `RequireAll` is included in the table, 
	the function only returns true if all listed permissions pass. Otherwise,
	it returns true if at least one permission passes.

	@param player Player -- The player to check
	@param permission Permission -- A table of permission strings or nested permission tables
	@return boolean -- Whether the player has the required permissions

	@within HasPermission
	@private
]=]
function tableCheck(player: Player, permission: Permission): boolean
	assert(typeof(permission) == "table", "Expected 'permission' to be a table")

	local requireAll = table.find(permission, "RequireAll")

	if requireAll then
		table.remove(permission, requireAll)
	end

	local grantedPermissions = {}
	for _, loop in permission do
		if not HasPermission(player, loop) then
			continue
		end
		table.insert(grantedPermissions, loop)
	end

	return if requireAll then #grantedPermissions == #permission else #grantedPermissions > 0
end

--[=[
	Parses and runs a string-based permission check using the `StringChecks` table.
	String permissions should follow the format `Prefix:Arg1:Arg2:...`.

	@param player Player -- The player to check
	@param permission Permission -- A string-based permission in the expected format
	@return boolean -- Whether the check passes

	@within HasPermission
	@private
]=]
function stringCheck(player: Player, permission: Permission): boolean
	assert(typeof(permission) == "string", "Expected 'permission' to be a string")

	local args: { string } = permission:split(":")
	local prefix: string = args[1]
	table.remove(args, 1)

	local isNegating: boolean = prefix:sub(1, 1) == "!"
	if isNegating then
		prefix = prefix:sub(2)
	end

	local check: ((Player, { string }) -> boolean)? = StringChecks[prefix]
	assert(typeof(check) == "function", `Could not find string check with prefix '{prefix}'`)

	local result: boolean = check(player, args)
	return if isNegating then not result else result
end

--[=[
	Checks if a player has a given permission. Delegates to either
	`tableCheck` or `stringCheck` based on the type of permission.

	@param player Player -- The player to check
	@param permission Permission -- The permission to evaluate
	@return boolean -- Whether the player has the permission

	@within HasPermission
]=]
function HasPermission(player: Player, permission: Permission): boolean
	if typeof(permission) == "table" then
		return tableCheck(player, permission)
	elseif typeof(permission) == "string" then
		return stringCheck(player, permission)
	end
	error("'Permission' must be a table or string")
end

return HasPermission
