--[[
	WallyProof.luau — Minimal proof that Wally packages load correctly.
	Requires the Promise package from ReplicatedStorage.Packages and returns true.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)

-- Verify the package loaded (Promise should be a table with .new method)
assert(typeof(Promise) == "table", "Promise package did not load correctly")
assert(typeof(Promise.new) == "function", "Promise.new is not a function")

return true
