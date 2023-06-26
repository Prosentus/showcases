local Table = {}
local seen = {}
local replacers = {
	["\""] = "\\\"",
	["\'"] = "\\\'",
	["\n"] = "\\n"
}
local ToString

local function ftype(val, _)
	return ("\"%s at %%p\""):format(type(val)):format(val)
end

local Types = {
	number = function(val, _)
		return ("%.99g"):format(val)
	end,
	string = function(val, _)
		val = val:gsub(".", replacers)
		return ("\"%s\""):format(val)
	end,
	["function"] = ftype,
	table = function(self, _size)
		if not seen[self] then
			seen[self] = self
			for key, value in pairs(self) do
				if type(value) == "table" and value[key] == value then
					local sAux = ("\"circular table at %p\""):format(value)
					seen[value] = nil
					return sAux
				end
			end
			return ToString(self, _size + 1)
		elseif seen[self] then
			for key, value in pairs(self) do
				if type(value) == "table" and not value[key] then
					return ToString(value, _size + 1)
				end
			end
			return ("\"circular table at %p\""):format(self)
		end
		return ("\"circular table at %p\""):format(self)
	end,
	thread = ftype,
	userdata = ftype
}

local sTab = ("\32"):rep(4)
local function selfType(parm, ...)
	return Types[type(parm)](parm, ...)
end

ToString = function(self, size)
	local strTb = "{\n"
	local hasContent = false
	size = type(size) == "number" and size or tonumber(size) or 1
	for key, value in pairs(self) do
		if not hasContent then
			hasContent = true
		end
		strTb = (strTb .. sTab:rep(size) .. "[%s] = %s,\n"):format(selfType(key, size), selfType(value, size))
	end
	if hasContent then
		strTb = strTb:reverse():sub(3):reverse() .. "\n" .. sTab:rep(size - 1) .. "}"
	else
		strTb = "{}"
	end

	return strTb
end

local mtTable = {
	__index = {
		forEach = function(self, cb)
			for key, value in pairs(self) do
				local received = {cb(key, value)}
				if rawlen(received) > 0 then
					return table.unpack(received)
				end
			end
		end,
		forEachI = function(self, cb)
			for key, value in ipairs(self) do
				local received = {cb(key, value)}
				if rawlen(received) > 0 then
					return table.unpack(received)
				end
			end
		end,
		pop = function(self)
			local val = self[rawlen(self)]
			if val then
				self[rawlen(self)] = nil
			end
		end,
		insert = function(self, key, value)
			return rawset(self, key, value)
		end,
		length = function(self)
			return rawlen(self)
		end,
		unpack = function(self)
			return table.unpack(self)
		end,
		clone = function(self)
			local clone = Table.new()
			clone.forEach(self, function(key, value)
				clone:insert(key, value)
			end)
			return clone
		end,
		reverse = function(self)
			local tbAux = self:clone()
			local count = 0
			for i = self:length(), 1, -1 do
				count = count + 1
				self:insert(i, tbAux[count])
			end
			return self
		end,
		concat = function(self, s)
			return table.concat(self, s or "")
		end
	},
	__tostring = function(self)
		local tbStr = ToString(self, 1)
		seen = {}
		return tbStr
	end
}

function Table.new(...)
	return setmetatable({...}, mtTable)
end

function Table.set(self)
	return setmetatable(self, mtTable)
end
mtTable = setmetatable(mtTable, mtTable)
Table = setmetatable(Table, setmetatable({
	__index = {
		methods = setmetatable(mtTable.__index, {
			__tostring = mtTable.__tostring
		})
	},
	__tostring = mtTable.__tostring
}, {
	__tostring = mtTable.__tostring
}))

return Table