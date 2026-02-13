module CRT
  module Bindings
    getter key_remaps : Hash(Int32, Int32) = {} of Int32 => Int32
    getter key_handlers : Hash(Int32, Proc(Int32?)) = {} of Int32 => Proc(Int32?)

    def remap_key(from_key : Int32, to_key : Int32)
      @key_remaps[from_key] = to_key
    end

    def remap_key(from_key : Char, to_key : Int32)
      remap_key(from_key.ord, to_key)
    end

    def on_key(key : Int32, &handler : -> Int32?)
      @key_handlers[key] = handler
    end

    def on_key(key : Char, &handler : -> Int32?)
      on_key(key.ord, &handler)
    end

    # Returns the (possibly remapped) key to process, or nil if a handler consumed it.
    # Handlers return nil to consume, or an Int32 key code to pass through
    # (same key or different for dynamic remapping).
    def resolve_key(input : Int32) : Int32?
      if handler = @key_handlers[input]?
        return handler.call
      end
      @key_remaps[input]? || input
    end

    def unbind_key(key : Int32)
      @key_remaps.delete(key)
      @key_handlers.delete(key)
    end

    def unbind_key(key : Char)
      unbind_key(key.ord)
    end

    def clear_key_bindings
      @key_remaps.clear
      @key_handlers.clear
    end
  end
end
