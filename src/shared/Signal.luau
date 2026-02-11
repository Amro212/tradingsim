--[[
	Signal.luau - Simple, clean event/signal implementation.
	This is a minimal Signal class for type-safe events.
	Alternative to BindableEvents with better memory management.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
	_connected: boolean,
}

export type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

-- Create a new Signal
function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({}, Signal)
	self._connections = {}
	return self
end

-- Connect a callback to the signal
function Signal:Connect(callback: (...any) -> ())
	assert(type(callback) == "function", "Callback must be a function")
	
	local connection = {
		_connected = true,
		_callback = callback,
		_signal = self,
	}
	
	function connection:Disconnect()
		if not self._connected then return end
		self._connected = false
		
		local index = table.find(self._signal._connections, self)
		if index then
			table.remove(self._signal._connections, index)
		end
	end
	
	table.insert(self._connections, connection)
	return connection
end

-- Fire the signal with arguments
function Signal:Fire(...)
	for _, connection in self._connections do
		if connection._connected then
			task.spawn(connection._callback, ...)
		end
	end
end

-- Wait for the signal to fire (yields)
function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

-- Disconnect all connections
function Signal:DisconnectAll()
	for _, connection in self._connections do
		connection._connected = false
	end
	table.clear(self._connections)
end

return Signal
