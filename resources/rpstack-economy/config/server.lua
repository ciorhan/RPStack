RPSTACK_ECONOMY_CONFIG = {}

-- Maximum single transaction amount (prevents overflow exploits)
RPSTACK_ECONOMY_CONFIG.maxTransactionAmount = tonumber(GetConvar('rpstack:economy:maxTransaction', '1000000'))

-- Starting balances for new characters
RPSTACK_ECONOMY_CONFIG.startingCash = tonumber(GetConvar('rpstack:economy:startingCash', '500'))
RPSTACK_ECONOMY_CONFIG.startingBank = tonumber(GetConvar('rpstack:economy:startingBank', '0'))