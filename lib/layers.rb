require 'narray'
module Rdmx
  class Layers < Array
    attr_accessor :universe, :compositor

    def initialize count, universe
      self.universe = universe
      self.compositor = :addition
      super(count){|i|Rdmx::Layer.new(self)}
    end

    def apply!
      universe.values.replace composite
    end

    def composite_base
      NArray.float(universe.values.size)
    end

    def alpha_compositor
      last = nil
      reverse.inject(composite_base) do |composite, layer|
        alpha = layer.alpha
        alpha -= last.alpha if last
        alpha = alpha.greater_of(0)
        masked = layer.values
        if last
          mask = last.values <= 0
          masked = masked * alpha
          masked[mask] = layer.values[mask]
        else
          masked *= alpha
        end
        composite += masked
        last = layer
        composite
      end
    end

    def addition_compositor
      inject(composite_base) do |composite, layer|
        composite + layer.values
      end
    end

    def last_on_top_compositor
      c = self[0...-1].inject(composite_base) do |composite, layer|
        composite + layer.values
      end
      last = self[-1]
      if last
        mask = self[-1].values > 0
        c[mask] = self[-1].values[mask]
      end
      c
    end

    # See http://en.wikipedia.org/wiki/Alpha_compositing
    def composite
      composite = send "#{self.compositor}_compositor"
      composite[composite.gt 255] = 255
      composite[composite.lt 0] = 0
      composite.to_i.to_a
    end

    def push *obj
      if obj.empty? || (obj.size == 1 && obj.first.is_a?(Integer))
        num = obj.pop || 1
        obj = num.times.map{Rdmx::Layer.new(self)}
      end
      super(*obj)
    end
  end

  class Layer
    attr_accessor :values, :fixtures, :parent, :alpha

    def initialize parent
      self.alpha = 1.0
      self.parent = parent
      self.values = NArray.float parent.universe.values.size
      self.fixtures = Rdmx::Universe::FixtureArray.new self,
        parent.universe.fixture_class
    end

    def [] *args
      values.send :[], *args
    end

    def []= *args
      values.send :[]=, *args
    end
  end
end
