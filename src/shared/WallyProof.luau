--[[
	WallyProof.luau — Proof that Wally packages load correctly.
	Verifies Promise, t (validation), and custom Signal implementation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wally packages
local Promise = require(ReplicatedStorage.Packages.Promise)
local t = require(ReplicatedStorage.Packages.t)

-- Custom shared modules
local Signal = require(ReplicatedStorage.Shared.Signal)

-- Verify Promise package
assert(typeof(Promise) == "table", "Promise package did not load correctly")
assert(typeof(Promise.new) == "function", "Promise.new is not a function")

-- Verify t (validation) package
assert(typeof(t) == "table", "t package did not load correctly")
assert(typeof(t.string) == "function", "t.string validator is not a function")
assert(typeof(t.number) == "function", "t.number validator is not a function")

-- Verify Signal implementation
assert(typeof(Signal) == "table", "Signal module did not load correctly")
assert(typeof(Signal.new) == "function", "Signal.new is not a function")

return true
