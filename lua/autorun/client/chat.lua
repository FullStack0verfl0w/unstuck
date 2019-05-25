net.Receive("AddChatText",function(len)
	local args = util.JSONToTable(util.Decompress(net.ReadData(len)))

	chat.AddText(unpack(args))
end)