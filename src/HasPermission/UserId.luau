--!strict
--!native

return function(player: Player, args: {string}): boolean
	return `{player.UserId}` == args[1]
end
