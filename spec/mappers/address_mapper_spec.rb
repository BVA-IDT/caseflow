describe AddressMapper do
  class AddressMapperClass
    include AddressMapper
  end

  context ".get_address_from_bgs_address()" do
    let(:address_line_1) { "1600 Pennsylvania Ave" }
    let(:address_line_2) { "NW" }
    let(:address_line_3) { "" }
    let(:city) { "Washington" }
    let(:state) { "DC" }
    let(:zip_code) { "20500" }
    let(:country) { "USA" }

    let(:bgs_address_template) do
      {
        addrs_one_txt: address_line_1,
        addrs_two_txt: address_line_2,
        addrs_three_txt: address_line_3,
        city_nm: city,
        postal_cd: state,
        zip_prefix_nbr: zip_code,
        cntry_nm: country
      }
    end
    let(:bgs_address) { bgs_address_template }

    let(:result_template) do
      {
        address_line_1: address_line_1,
        address_line_2: address_line_2,
        address_line_3: address_line_3,
        city: city,
        country: country,
        state: state,
        zip: zip_code
      }
    end
    let(:result) { result_template }

    subject { AddressMapperClass.new.get_address_from_bgs_address(bgs_address) }

    context "when no input argument is provided" do
      let(:bgs_address) { nil }
      let(:result) { {} }

      it "returns an empty hash" do
        expect(subject).to eq(result)
      end
    end

    context "when input argument contains all expected fields" do
      it "returns hash with keys renamed" do
        expect(subject).to eq(result)
      end
    end

    context "when input argument contains incomplete set of expected fields" do
      let(:bgs_address) { bgs_address_template.except(:zip_prefix_nbr) }
      let(:zip_code) { nil }

      it "returns hash with nil value for the absent field" do
        expect(subject).to eq(result)
      end
    end

    context "when input argument contains additional fields" do
      let(:bgs_address) { bgs_address_template.merge(additional_field: "additional value") }

      it "returns hash with only the fields we care about" do
        expect(subject).to eq(result)
      end
    end
  end

  context ".get_name_and_address_from_bgs_info()" do
    let(:name) { "Whitmore Marilyn" }
    let(:relationship) { "Spouse" }

    let(:bgs_info_template) do
      {
        payee_name: name,
        payee_type_name: relationship
      }
    end
    let(:bgs_info) { bgs_info_template }

    let(:result_template) do
      {
        name: name,
        relationship: relationship
      }
    end
    let(:result) { result_template }

    subject { AddressMapperClass.new.get_name_and_address_from_bgs_info(bgs_info) }

    context "when no input argument is provided" do
      let(:bgs_info) { nil }
      let(:result) { {} }

      it "returns an empty hash" do
        expect(subject).to eq(result)
      end
    end

    context "when input argument contains all expected fields" do
      it "returns hash with keys renamed" do
        expect(subject).to eq(result)
      end
    end

    context "when input argument contains incomplete set of expected fields" do
      let(:bgs_info) { bgs_info_template.except(:payee_type_name) }
      let(:relationship) { nil }

      it "returns hash with nil value for the absent field" do
        expect(subject).to eq(result)
      end
    end

    context "when input argument contains additional fields" do
      let(:bgs_address) { bgs_address_template.merge(additional_field: "additional value") }

      it "returns hash with only the fields we care about" do
        expect(subject).to eq(result)
      end
    end

    context "when input name field contains many spaces between first and last name" do
      let(:name_with_many_spaces) { name.gsub(/\s+/, "          ") }
      let(:result) { result_template.merge(name: name_with_many_spaces) }

      it "returns name with multiple spaces reduced to single space" do
        expect(subject[:name]).to eq(name)
      end
    end
  end
end
