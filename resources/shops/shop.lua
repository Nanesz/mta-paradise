--[[
Copyright (c) 2010 MTA: Paradise

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
]]

local shops = { }

local function createShopPed( shopID )
	local shop = shops[ shopID ]
	if shop then
		local ped = createPed( shop.skin ~= 0 and shop.skin or shop_configurations[ shop.configuration ].skin, shop.x, shop.y, shop.z, shop.rotation )
		if ped then
			shops[ ped ] = shopID
			
			setPedRotation( ped, shop.rotation )
			setElementInterior( ped, shop.interior )
			setElementDimension( ped, shop.dimension )
			setPedFrozen( ped, true )
			
			return true
		end
	end
	outputDebugString( "Failed to create Shop " .. tostring( shopID ) )
	return false
end

addEventHandler( "onPedWasted", resourceRoot,
	function( )
		local shopID = shops[ source ]
		if shopID then
			shops[ source ] = nil
			destroyElement( source )
			
			createShopPed( shopID )
		end
	end
)

local function loadShop( shopID, x, y, z, rotation, interior, dimension, configuration, skin )
	shops[ shopID ] = { x = x, y = y, z = z, rotation = rotation, interior = interior, dimension = dimension, configuration = configuration, skin = skin }
	if not createShopPed( shopID ) then
		outputDebugString( "shop creation failed: shop " .. tostring( shopID ) )
	end
end

addEventHandler( "onResourceStart", resourceRoot,
	function( )
		local result = exports.sql:query_assoc( "SELECT * FROM shops ORDER BY shopID ASC" )
		if result then
			for key, data in ipairs( result ) do
				loadShop( data.shopID, data.x, data.y, data.z, data.rotation, data.interior, data.dimension, data.configuration, data.skin )
			end
		end
	end
)

addCommandHandler( "createshop",
	function( player, commandName, config )
		if config then
			if shop_configurations[ config ] then
				local x, y, z = getElementPosition( player )
				local rotation = getPedRotation( player )
				local interior = getElementInterior( player )
				local dimension = getElementDimension( player )
				
				local shopID = exports.sql:query_insertid( "INSERT INTO shops (x, y, z, rotation, interior, dimension, configuration) VALUES (" .. table.concat( { x, y, z, rotation, interior, dimension, '"%s"' }, ", " ) .. ")", config )
				if shopID then
					loadShop( shopID, x, y, z, rotation, interior, dimension, config, 0 )
					
					outputChatBox( "Created new shop with ID " .. shopID .. ", type is " .. config .. ".", player, 0, 255, 0 )
				else
					outputChatBox( "Shop creation failed (SQL-Error).", player, 255, 0, 0 )
				end
			else
				outputChatBox( "There is no configuration named '" .. config .. "'.", player, 255, 0, 0 )
			end
		else
			outputChatBox( "Syntax: /" .. commandName .. " [type]", player, 255, 255, 255 )
		end
	end
)

-- client interaction

local p = { }

addEventHandler( "onElementClicked", resourceRoot,
	function( button, state, player )
		if button == "left" and state == "up" then
			local shopID = shops[ source ]
			if shopID then
				local shop = shops[ shopID ]
				if shop then
					if shop_configurations[ shop.configuration ] then
						p[ player ] = { shopID = shopID }
						triggerClientEvent( player, "shops:open", source, shop.configuration )
					end
				end
			end
		end
	end
)

addEventHandler( "onPlayerQuit", root,
	function( )
		p[ source ] = nil
	end
)

addEvent( "shops:close", true )
addEventHandler( "shop:close", root,
	function( )
		if source == client then
			p[ source ] = nil
		end
	end
)

addEvent( "shops:buy", true )
addEventHandler( "shops:buy", root,
	function( key )
		if source == client and type( key ) == "number" then
			-- check if the player is even meant to shop, if so only the index is transferred so we need to know where
			if p[ source ] then
				local shop = shops[ p[ source ].shopID ]
				if shop then
					-- check if it's a valid item
					local item = shop.items and shop.items[ key ] or shop_configurations[ shop.configuration ][ key ]
					if item then
						if exports.players:takeMoney( source, item.price ) then
							if exports.items:give( source, item.itemID, item.itemValue, item.name ) then
								outputChatBox( "You've bought a " .. ( item.name or exports.items:getName( item.itemID ) ) .. " for $" .. item.price .. ".", source, 0, 255, 0 )
							end
						else
							outputChatBox( "You can't afford to buy a " .. ( item.name or exports.items:getName( item.itemID ) ) .. ".", source, 0, 255, 0 )
						end
					end
				end
			end
		end
	end
)
