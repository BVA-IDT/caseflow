# frozen_string_literal: true

class Fakes::Vets360Service < ExternalApi::Vets360Service
  def self.geocode(_address)
    [0.0, 0.0]
  end
end
