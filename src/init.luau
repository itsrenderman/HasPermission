--!strict
--!native
--!optimize 2

const LogService = game:GetService("LogService")
const RunService = game:GetService("RunService")

--[=[
	@type Permission string | "RequireAll" | {Permission}

	The type definition for the 'Permission' callback parameter of [HasPermission:Check]

	@within HasPermission
]=]
type Permission = string | "RequireAll" | { Permission }

--[=[
	@type Check (player: Player, args: { string }) -> boolean

	The type definition for the 'Check' callback parameter of [HasPermission:Register]

	@within HasPermission
]=]
type Check = (Player, { string }) -> boolean

--[=[
	@class HasPermission

	Provides a way to check permissions for different users. Supports various checks, and allows for complex logic such as:
	- `"UserId:1234"`
	- `{"UserId:1234", "UserId:5678"}`
	- `{"!UserId:1234", "!UserId:5678", "RequireAll"}`
	- `{{"UserId:1", "Name:Roblox", "RequireAll"}, {"UserId:156", "Name:builderman", "RequireAll"}, "Admin"}`
]=]
--[=[
	@prop _Debug boolean
	Should the module print informative debug messages to the output

	@private
	@within HasPermission
]=]
--[=[
	@prop _CheckLocateAttempts number
	How many attempts should the module try to locate a permission check

	@private
	@within HasPermission
]=]
--[=[
	@prop _CheckLocateRetryDelaySeconds number
	The interval of seconds between re-trying to locate a perimssion check

	@private
	@within HasPermission
]=]
--[=[
	@prop _Checks { [string]: Check }
	The dictionary of checks registered to the module

	@private
	@within HasPermission
]=]
const HasPermission = {
	_Debug = false,
	_CheckLocateAttempts = 3,
	_CheckLocateRetryDelaySeconds = 1,
	_Checks = {},
}

--[=[
	Checks a table of permissions. If `RequireAll` is included in the table, 
	the function only returns true if all listed permissions pass. Otherwise,
	it returns true if at least one permission passes.

	@param player Player -- The player to check
	@param permission Permission -- A table of permission strings or nested permission tables
	@return boolean -- Whether the player has the required permissions

	@private
	@within HasPermission
]=]
function HasPermission:_TableCheck(player: Player, permission: Permission): boolean
	assert(typeof(player) == "Instance", `Expected argument 1 'Player' to be an Instance, got '{typeof(player)}'`)
	assert(player:IsA("Player"), `Expected argument 1 'Player' to be a Player, got '{player.ClassName}'`)
	assert(typeof(permission) == "table", `Expected argument 2 'Permission' to be a table, got '{typeof(permission)}'`)

	local requireAll: number? = table.find(permission, "RequireAll")
	if requireAll then
		table.remove(permission, requireAll)
	end

	if #permission == 0 then
		return true
	end

	local grantedPermissions: { Permission } = {}
	for _, loop in permission do
		if not HasPermission:Check(player, loop) then
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

	@private
	@within HasPermission
]=]
function HasPermission:_StringCheck(player: Player, permission: Permission): boolean
	assert(typeof(player) == "Instance", `Expected argument 1 'Player' to be an Instance, got '{typeof(player)}'`)
	assert(player:IsA("Player"), `Expected argument 1 'Player' to be a Player, got '{player.ClassName}'`)
	assert(
		typeof(permission) == "string",
		`Expected argument 2 'Permission' to be a string, got '{typeof(permission)}'`
	)

	local args: { string } = permission:split(":")
	local checkName: string = args[1]
	table.remove(args, 1)

	local isNegating: boolean = checkName:sub(1, 1) == "!"
	if isNegating then
		checkName = checkName:sub(2)
	end

	local check: ((Player, { string }) -> boolean)?
	local attempts: number = 0
	while attempts < HasPermission._CheckLocateAttempts do
		check = HasPermission._Checks[checkName]
		if check then
			break
		end
		attempts += 1
		if attempts == HasPermission._CheckLocateAttempts then
			break
		end
		if HasPermission._Debug then
			LogService:Warn(
				`Attempt {attempts}/{HasPermission._CheckLocateAttempts}: Could not find permission check '{checkName}', re-trying in {HasPermission._CheckLocateRetryDelaySeconds}s`
			)
			LogService:Info(debug.traceback())
		end
		task.wait(HasPermission._CheckLocateRetryDelaySeconds)
	end
	assert(
		typeof(check) == "function",
		`Attempt {attempts}/{HasPermission._CheckLocateAttempts}: Could not find permission check '{checkName}'`
	)

	local result: boolean = check(player, args)
	return if isNegating then not result else result
end

--[=[
	Checks if a player has a given permission. Delegates to either
	`tableCheck` or `stringCheck` based on the type of permission.
	- Use '!' before a check name to check if the permission is NOT granted.

	@param player Player -- The player to check
	@param permission Permission -- The permission to evaluate
	@return boolean -- Whether the player has the permission

	@within HasPermission
]=]
function HasPermission:Check(player: Player, permission: Permission): boolean
	assert(typeof(player) == "Instance", `Expected argument 1 'Player' to be an Instance, got '{typeof(player)}'`)
	assert(player:IsA("Player"), `Expected argument 1 'Player' to be a Player, got '{player.ClassName}'`)

	if typeof(permission) == "table" then
		return HasPermission:_TableCheck(player, permission)
	elseif typeof(permission) == "string" then
		return HasPermission:_StringCheck(player, permission)
	end
	error(`Expected argument 2 'Permission' to be table or string, got '{typeof(permission)}'`)
end

--[=[
	Returns true if a permission check 

	@param name Name -- The name of the check

	@within HasPermission
]=]
function HasPermission:Exists(name: string): boolean
	assert(typeof(name) == "string", `Expected argument 1 'Name' to be a string, got '{typeof(name)}'`)
	return HasPermission._Checks[name] ~= nil
end

--[=[
	Registers a new permission check
	- Errors if a check with same name already exists

	@param name Name -- The name of the check
	@param callback Check -- The function to call for the permission check which should return a boolean
	
	@return boolean -- Whether the permission check has been registered

	@within HasPermission
]=]
function HasPermission:Register(name: string, callback: Check): ()
	assert(typeof(name) == "string", `Expected argument 1 'Name' to be a string, got '{typeof(name)}'`)
	assert(not HasPermission._Checks[name], `Permission check '{name}' has already been registered`)
	assert(typeof(callback) == "function", `Expected argument 2 'Callback' to be a function, got '{typeof(callback)}'`)

	HasPermission._Checks[name] = callback
	if RunService:IsStudio() then
		LogService:Warn(`Registered permission check '{name}'`)
		LogService:Info(debug.traceback())
	end
end

--[=[
	Unregisters a permission check used against players.

	@param name Name -- The name of the check

	@within HasPermission
]=]
function HasPermission:Unregister(name: string): ()
	assert(typeof(name) == "string", `Expected argument 1 'Name' to be a string, got '{typeof(name)}'`)

	if not HasPermission._Checks[name] then
		if HasPermission._Debug then
			LogService:Warn(`Attempted to un-register permission check '{name}', but it already does not exist`)
			LogService:Info(debug.traceback())
		end
		return
	end

	HasPermission._Checks[name] = nil
	if RunService:IsStudio() then
		LogService:Warn(`Un-registered permission check '{name}'`)
		LogService:Info(debug.traceback())
	end
end

return HasPermission
