local config = require 'config'

--
--  FUNCTIONS
--



-- 
--  THREADS
--



--
-- EVENTS
--

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
	Wait(2000)
    
    -- Get active spikes

end)

--
--  EXPORTS
--

exports('useRoll', function(data, slot)

    print('Using Roll')

end)

exports('useDeployer', function(data, slot)

    print('Using Deployer')

end)

exports('useRemote', function(data, slot)

    print('Using Remote')

end)

-- 
--  HANDLERS
--

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end

	-- Clean up
	
end)