net.Receive("AddChatText",function(len)
	local args = net.ReadTable()

	chat.AddText(unpack(args))
end)