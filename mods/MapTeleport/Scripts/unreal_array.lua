-- UE4SS f58 TArray:ForEach retains a raw userdata pointer while invoking Lua.
-- Its own implementation documents a GC/stack crash on large arrays. Keep the
-- array rooted in Lua and read one element at a time, without that C iterator.
local Array={}
function Array.each(array,callback)
    local count=array:GetArrayNum()
    assert(type(count)=='number'and count>=0 and count%1==0,'Invalid Unreal array size')
    for i=1,count do
        -- In this build even an out-of-range READ can grow the engine array.
        -- Never perform one if a callback changed the underlying container.
        assert(array:GetArrayNum()==count,'Unreal array changed during read')
        local stop=callback(i,array[i])
        -- This use also roots the array until the callback has returned.
        assert(array:GetArrayNum()==count,'Unreal array changed during read')
        if stop then break end
    end
end
return Array
