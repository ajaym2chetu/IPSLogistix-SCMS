require "rails_helper"

RSpec.describe ShipmentScreener, vcr: true do
  before do
    create(:screening_keyword, :dangerous_goods, keyword: "gun")
    create(:screening_keyword, :dangerous_goods, :with_guidelines, :with_procedures, keyword: "chemical")
    create(:screening_keyword, :dangerous_goods, keyword: "samsung galaxy note 7")
    create(:screening_keyword, :prohibited_goods, keyword: "vibrator", destination_country_alpha2: "ID")
    create(:screening_keyword, :prohibited_goods, keyword: "soap")
    create(:screening_keyword, :prohibited_goods, :allowed, keyword: "soap", destination_country_alpha2: "CA")
    create(:screening_keyword, :prohibited_goods, keyword: "doll", courier_admin_name: "DHLeCommerce_ParcelDirect")
    create(:screening_keyword, :prohibited_goods, keyword: "doll", courier_admin_name: "SkyPostal_All")
  end

  let!(:screener) { ShipmentScreener.new(shipment: shipment, screen_for: screen_for) }
  let!(:shipment) { create(:shipment, destination_name: destination_name, destination_country_id: destination_country_id) }
  let!(:shipment_item) { create(:shipment_item, shipment: shipment, description: item_description) }

  let(:destination_name) { "Joe Lanes" }
  let(:destination_country_id) { 199 } # Singapore
  let(:item_description) { "T-Shirt" }

  before do
    screener.process
    shipment.save
  end

  subject { shipment.screening_flags[0] }

  describe "Dangerous Goods" do
    let(:screen_for) { [:dangerous_goods] }

    context "when no dangerous_goods can be found" do
      it { is_expected.to be_nil }
    end

    context "when there are dangerous_goods" do
      let(:item_description) { "Gun Ammonition" }
      it {
        is_expected.to have_attributes({
          category: "dangerous_goods", label: "Inspection", keyword: "gun",
          screening_guidelines: nil, operating_procedures: nil
        })
      }
    end

    context "when there are dangerous_goods (forbideen name in full description)" do
      let(:item_description) { "Chemical Play Set for Kid" }
      it {
        is_expected.to have_attributes({
          category: "dangerous_goods", label: "Inspection", keyword: "chemical",
          screening_guidelines: "Verify the content carefully", operating_procedures: "Keep on hold"
        })
      }
    end

    context "when there are dangerous_goods (in plural form)" do
      let(:item_description) { "Chemicals" }
      it {
        is_expected.to have_attributes({
          category: "dangerous_goods", label: "Inspection", keyword: "chemicals",
          screening_guidelines: "Verify the content carefully", operating_procedures: "Keep on hold"
        })
      }
    end
    context "when there are dangerous_goods" do
      let(:item_description) { "Samsung Galaxy Note 7" }
      it { is_expected.to have_attributes({category: "dangerous_goods", label: "Inspection", keyword: "samsung galaxy note 7"}) }
    end

    context "when no dangerous_goods can be found (name is close to a dangerous_goods)" do
      let(:item_description) { "Samsung Galaxy Note 8" }
      it { is_expected.to be_nil }
    end

    context "when no dangerous_goods can be found (name is a substring of a dangerous_goods)" do
      let(:item_description) { "sparrow" } # close to arrow
      it { is_expected.to be_nil }
    end
  end

  describe "Prohibited Goods" do
    let(:screen_for) { [:prohibited_goods] }

    context "when no prohibited_goods can be found" do
      it { is_expected.to be_nil }
    end

    context "when there are prohibited_goods" do
      let(:item_description) { "Sex vibrator" }

      context "when the country does not prohibit it" do
        let(:destination_country_id) { 76 } # France

        it { is_expected.to be_nil }
      end

      context "when the country prohibits it" do
        let(:destination_country_id) { 102 } # Indonesia

        it { is_expected.to have_attributes({category: "prohibited_goods", label: "Inspection", destination_country_name: "Indonesia", keyword: "vibrator"}) }
      end
    end

    context "when a prohibited good is allowed for certain countries" do
      context "soap" do
        let(:destination_country_id) { 39 } # Canada
        let(:item_description) { "Soap Bar" }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "Denied Party" do
    let(:screen_for) { [:denied_party] }

    context "when the receiver is not on a screening list" do
      it { is_expected.to be_nil }
    end

    context "when the receiver is on a screening list" do
      let(:destination_name) { "Yasir Abbas" }
      it { is_expected.to have_attributes({category: "denied_party", label: "Hold", denied_party_name: "'ABBAS, Yasir", source: "Specially Designated Nationals (SDN) - Treasury Department"}) }
    end

    context "when the API returns an error" do
      it { is_expected.to be_nil }
    end
  end

  describe "#screen_for_prohibited_goods_by_courier" do
    let(:screen_for) { [:prohibited_goods_by_courier] }

    context "doll" do
      let(:shipment) { create(:shipment, :to_mx) }
      let(:item_description) { "Doll House" }

      it "sets prohibited couriers" do
        expect(shipment.order_data["couriers_excluded_due_to_prohibited_goods"]).to include("DHLeCommerce_ParcelDirect", "SkyPostal_All")
      end
    end

    context "all good" do
      let(:shipment) { create(:shipment, :to_mx) }
      let(:item_description) { "all good" }

      it "does not set prohibited couriers" do
        expect(shipment.order_data["couriers_excluded_due_to_prohibited_goods"]).to be_nil
      end
    end
  end
end
