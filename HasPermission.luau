--!strict
--!native

type Permission = string | "RequireAll" | {Permission}

local StringChecks: {
	[string]: (Player, {string}) -> boolean
} = {
	UserId = require(script.UserId)
}

function tableCheck(player: Player, permission: Permission): boolean
	assert(typeof(permission) == "table", "Expected 'permission' to be a table")

	local requireAll = table.find(permission, "RequireAll")
	if requireAll then table.remove(permission, requireAll) end

	local grantedPermissions = {}
	for _, loop in permission do
		if not HasPermission(player, loop) then continue end
		table.insert(grantedPermissions, loop)
	end
	
	return if requireAll then #grantedPermissions == #permission else #grantedPermissions > 0
end

function stringCheck(player: Player, permission: Permission): boolean
	assert(typeof(permission) == "string", "Expected 'permission' to be a string")

	local args = permission:split(":")
	local prefix = args[1]
	table.remove(args, 1)

	local check = StringChecks[prefix]
	assert(typeof(check) == "function", `Could not find string check with prefix '{prefix}'`)

	return check(player, args)
end

function HasPermission(player: Player, permission: Permission): boolean
	if typeof(permission) == "table" then
		return tableCheck(player, permission)
	elseif typeof(permission) == "string" then
		return stringCheck(player, permission)
	end
	error("'Permission' must be a table or string")
end

return HasPermission
