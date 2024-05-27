local bufferCreate = buffer.create
local bufferWriteU8 = buffer.writeu8
local bufferReadU8 = buffer.readu8
local bufferReadU32 = buffer.readu32
local bufferLen = buffer.len

local bit32Byteswap = bit32.byteswap
local bit32RShift = bit32.rshift
local bit32Byteswap = bit32.byteswap
local bit32Band = bit32.band
local bit32LShift = bit32.lshift
local bit32Bor = bit32.bor

local stringByte = string.byte

local mathCeil = math.ceil



local lookupValueToCharacter = bufferCreate(64)
local lookupCharacterToValue = bufferCreate(256)

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local padding = stringByte("=")

for index = 1, 64 do
	local value = index - 1
	local character = stringByte(alphabet, index)
	
	bufferWriteU8(lookupValueToCharacter, value, character)
	bufferWriteU8(lookupCharacterToValue, character, value)
end

local function encode(input: buffer): buffer
	local inputLength = bufferLen(input)
	local inputChunks = mathCeil(inputLength / 3)
	
	local outputLength = inputChunks * 4
	local output = bufferCreate(outputLength)
	
	-- Since we use readu32 and chunks are 3 bytes large, we can't read the last chunk here
	for chunkIndex = 1, inputChunks - 1 do
		local inputIndex = (chunkIndex - 1) * 3
		local outputIndex = (chunkIndex - 1) * 4
		
		local chunk = bit32Byteswap(bufferReadU32(input, inputIndex))
		
		-- 8 + 24 - (6 * index)
		local value1 = bit32RShift(chunk, 26)
		local value2 = bit32Band(bit32RShift(chunk, 20), 0b111111)
		local value3 = bit32Band(bit32RShift(chunk, 14), 0b111111)
		local value4 = bit32Band(bit32RShift(chunk, 8), 0b111111)
		
		bufferWriteU8(output, outputIndex, bufferReadU8(lookupValueToCharacter, value1))
		bufferWriteU8(output, outputIndex + 1, bufferReadU8(lookupValueToCharacter, value2))
		bufferWriteU8(output, outputIndex + 2, bufferReadU8(lookupValueToCharacter, value3))
		bufferWriteU8(output, outputIndex + 3, bufferReadU8(lookupValueToCharacter, value4))
	end
	
	local inputRemainder = inputLength % 3
	
	if inputRemainder == 1 then
		local chunk = bufferReadU8(input, inputLength - 1)
		
		local value1 = bit32RShift(chunk, 2)
		local value2 = bit32Band(bit32LShift(chunk, 4), 0b111111)

		bufferWriteU8(output, outputLength - 4, bufferReadU8(lookupValueToCharacter, value1))
		bufferWriteU8(output, outputLength - 3, bufferReadU8(lookupValueToCharacter, value2))
		bufferWriteU8(output, outputLength - 2, padding)
		bufferWriteU8(output, outputLength - 1, padding)
	elseif inputRemainder == 2 then
		local chunk = bit32Bor(
			bit32LShift(bufferReadU8(input, inputLength - 2), 8),
			bufferReadU8(input, inputLength - 1)
		)

		local value1 = bit32RShift(chunk, 10)
		local value2 = bit32Band(bit32RShift(chunk, 4), 0b111111)
		local value3 = bit32Band(bit32LShift(chunk, 2), 0b111111)
		
		bufferWriteU8(output, outputLength - 4, bufferReadU8(lookupValueToCharacter, value1))
		bufferWriteU8(output, outputLength - 3, bufferReadU8(lookupValueToCharacter, value2))
		bufferWriteU8(output, outputLength - 2, bufferReadU8(lookupValueToCharacter, value3))
		bufferWriteU8(output, outputLength - 1, padding)
	elseif inputRemainder == 0 and inputLength ~= 0 then
		local chunk = bit32Bor(
			bit32LShift(bufferReadU8(input, inputLength - 3), 16),
			bit32LShift(bufferReadU8(input, inputLength - 2), 8),
			bufferReadU8(input, inputLength - 1)
		)

		local value1 = bit32RShift(chunk, 18)
		local value2 = bit32Band(bit32RShift(chunk, 12), 0b111111)
		local value3 = bit32Band(bit32RShift(chunk, 6), 0b111111)
		local value4 = bit32Band(chunk, 0b111111)

		bufferWriteU8(output, outputLength - 4, bufferReadU8(lookupValueToCharacter, value1))
		bufferWriteU8(output, outputLength - 3, bufferReadU8(lookupValueToCharacter, value2))
		bufferWriteU8(output, outputLength - 2, bufferReadU8(lookupValueToCharacter, value3))
		bufferWriteU8(output, outputLength - 1, bufferReadU8(lookupValueToCharacter, value4))
	end
	
	return output
end

local function decode(input: buffer): buffer
	local inputLength = bufferLen(input)
	local inputChunks = mathCeil(inputLength / 4)
	
	-- TODO: Support input without padding
	local inputPadding = 0
	if inputLength ~= 0 then
		if bufferReadU8(input, inputLength - 1) == padding then inputPadding += 1 end
		if bufferReadU8(input, inputLength - 2) == padding then inputPadding += 1 end
	end

	local outputLength = inputChunks * 3 - inputPadding
	local output = bufferCreate(outputLength)
	
	for chunkIndex = 1, inputChunks - 1 do
		local inputIndex = (chunkIndex - 1) * 4
		local outputIndex = (chunkIndex - 1) * 3
		
		local value1 = bufferReadU8(lookupCharacterToValue, bufferReadU8(input, inputIndex))
		local value2 = bufferReadU8(lookupCharacterToValue, bufferReadU8(input, inputIndex + 1))
		local value3 = bufferReadU8(lookupCharacterToValue, bufferReadU8(input, inputIndex + 2))
		local value4 = bufferReadU8(lookupCharacterToValue, bufferReadU8(input, inputIndex + 3))
		
		local chunk = bit32Bor(
			bit32LShift(value1, 18),
			bit32LShift(value2, 12),
			bit32LShift(value3, 6),
			value4
		)
		
		local character1 = bit32RShift(chunk, 16)
		local character2 = bit32Band(bit32RShift(chunk, 8), 0b11111111)
		local character3 = bit32Band(chunk, 0b11111111)
		
		bufferWriteU8(output, outputIndex, character1)
		bufferWriteU8(output, outputIndex + 1, character2)
		bufferWriteU8(output, outputIndex + 2, character3)
	end
	
	if inputLength ~= 0 then
		local lastInputIndex = (inputChunks - 1) * 4
		local lastOutputIndex = (inputChunks - 1) * 3
		
		local lastValue1 = bufferReadU8(lookupCharacterToValue, bufferReadU8(input, lastInputIndex))
		local lastValue2 = bufferReadU8(lookupCharacterToValue, bufferReadU8(input, lastInputIndex + 1))
		local lastValue3 = bufferReadU8(lookupCharacterToValue, bufferReadU8(input, lastInputIndex + 2))
		local lastValue4 = bufferReadU8(lookupCharacterToValue, bufferReadU8(input, lastInputIndex + 3))

		local lastChunk = bit32Bor(
			bit32LShift(lastValue1, 18),
			bit32LShift(lastValue2, 12),
			bit32LShift(lastValue3, 6),
			lastValue4
		)
		
		if inputPadding <= 2 then
			local lastCharacter1 = bit32RShift(lastChunk, 16)
			bufferWriteU8(output, lastOutputIndex, lastCharacter1)
			
			if inputPadding <= 1 then
				local lastCharacter2 = bit32Band(bit32RShift(lastChunk, 8), 0b11111111)
				bufferWriteU8(output, lastOutputIndex + 1, lastCharacter2)
				
				if inputPadding == 0 then
					local lastCharacter3 = bit32Band(lastChunk, 0b11111111)
					bufferWriteU8(output, lastOutputIndex + 2, lastCharacter3)
				end
			end
		end
	end
	
	return output
end

return {
	encode = encode,
	decode = decode,
}
