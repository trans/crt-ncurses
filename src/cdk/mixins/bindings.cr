module CDK
  module Bindings
    alias BindingCallback = Proc(Symbol, CDK::CDKObjs, Nil, Int32, Bool)

    getter binding_list : Hash(Int32, {BindingCallback | Symbol, Int32?}) = {} of Int32 => {BindingCallback | Symbol, Int32?}

    def init_bindings
      @binding_list = {} of Int32 => {BindingCallback | Symbol, Int32?}
    end

    def bindable_object(cdktype : Symbol) : CDK::CDKObjs?
      return nil if cdktype != self.object_type
      self.as(CDK::CDKObjs)
    end

    def bind(type : Symbol, key : Int32, function : BindingCallback | Symbol, data : Int32? = nil)
      obj = self.bindable_object(type)
      return if obj.nil?
      obj.binding_list[key] = {function, data} if key != 0
    end

    def unbind(type : Symbol, key : Int32)
      obj = self.bindable_object(type)
      return if obj.nil?
      obj.binding_list.delete(key)
    end

    def clean_bindings(type : Symbol)
      obj = self.bindable_object(type)
      return if obj.nil?
      obj.binding_list.clear
    end

    def check_bind(type : Symbol, key : Int32) : Bool | Int32
      obj = self.bindable_object(type)
      if !obj.nil? && obj.binding_list.has_key?(key)
        function = obj.binding_list[key][0]
        data = obj.binding_list[key][1]

        if function.is_a?(Symbol) && function == :getc
          return data || 0
        elsif function.is_a?(BindingCallback)
          return function.call(type, obj, nil, key)
        end
      end
      false
    end

    def is_bind?(type : Symbol, key : Int32) : Bool
      obj = self.bindable_object(type)
      return false if obj.nil?
      obj.binding_list.has_key?(key)
    end
  end
end
