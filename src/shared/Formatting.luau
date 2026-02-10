--[[
	Formatting.luau — Display helpers for currency, percentages, and quantities.
	Used by both server (trade result messages) and client (UI labels).
]]

local Formatting = {}

-- Format number as cash: "$1,234.56"
function Formatting.formatCash(n: number): string
	if n ~= n then return "$0.00" end -- NaN guard
	local negative = n < 0
	n = math.abs(n)
	local int = math.floor(n)
	local dec = math.floor((n - int) * 100 + 0.5)
	local intStr = tostring(int)
	-- Add comma separators
	local formatted = ""
	local len = #intStr
	for i = 1, len do
		if i > 1 and (len - i + 1) % 3 == 0 then
			formatted = formatted .. ","
		end
		formatted = formatted .. intStr:sub(i, i)
	end
	local result = "$" .. formatted .. "." .. string.format("%02d", dec)
	if negative then
		result = "-" .. result
	end
	return result
end

-- Format percentage: "+12.34%" or "-5.67%"
function Formatting.formatPct(n: number): string
	if n ~= n then return "0.00%" end
	local sign = n >= 0 and "+" or ""
	return sign .. string.format("%.2f", n * 100) .. "%"
end

-- Format quantity cleanly
function Formatting.formatQty(n: number): string
	if n ~= n then return "0" end
	if n == math.floor(n) then
		return tostring(math.floor(n))
	end
	return string.format("%.4f", n)
end

-- Short number: 1.2K, 3.4M, etc.
function Formatting.shortNumber(n: number): string
	if n ~= n then return "0" end
	local abs = math.abs(n)
	local sign = n < 0 and "-" or ""
	if abs >= 1e9 then
		return sign .. string.format("%.1fB", abs / 1e9)
	elseif abs >= 1e6 then
		return sign .. string.format("%.1fM", abs / 1e6)
	elseif abs >= 1e3 then
		return sign .. string.format("%.1fK", abs / 1e3)
	else
		return sign .. string.format("%.2f", abs)
	end
end

-- Format price with appropriate decimal places
function Formatting.formatPrice(n: number): string
	if n ~= n then return "$0.00" end
	if n >= 100 then
		return "$" .. string.format("%.2f", n)
	elseif n >= 1 then
		return "$" .. string.format("%.4f", n)
	else
		return "$" .. string.format("%.6f", n)
	end
end

-- Timestamp to readable: "12:34:56"
function Formatting.formatTime(t: number): string
	local hours = math.floor(t / 3600) % 24
	local mins = math.floor(t / 60) % 60
	local secs = math.floor(t) % 60
	return string.format("%02d:%02d:%02d", hours, mins, secs)
end

return Formatting
