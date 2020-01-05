sfutil = {}

--------------------------------------------------------------------------------
--- Yields until a promise is finished, or immediately if running on the main
-- thread
-- @param promise RpcMessage - the promise to await
-- @returns Return the promise when finished
function sfutil.safe_await(promise)
    if not coroutine.running() == nil then
        while not promise:finished() do
            coroutine.yield()
        end
    end
  return promise
end
--------------------------------------------------------------------------------
