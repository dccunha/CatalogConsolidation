require "rails_helper"

RSpec.describe Intake::Services::ComparisonNormalizer, type: :model do
  describe ".normalize" do
    it "equates accents, case, and Unicode whitespace" do
      expect(described_class.normalize(" \u00a0 CÂMERA\t  WiFi  \n")).to eq("camera wifi")
    end

    it "uses Unicode case folding for the German sharp s" do
      expect(described_class.normalize("Straße")).to eq(described_class.normalize("STRASSE"))
    end

    it "keeps punctuation differences" do
      expect(described_class.normalize("Tablet iPad Pro 12.9''")).not_to eq(
        described_class.normalize('Tablet iPad Pro 12.9"')
      )
    end

    it "keeps capacity and model tokens" do
      expect(described_class.normalize("Phone X 128GB")).not_to eq(described_class.normalize("Phone X 256GB"))
    end

    it "does not rewrite compatibility number or punctuation characters" do
      expect([ described_class.normalize("Model ①"), described_class.normalize("Model １．０") ]).not_to eq(
        [ described_class.normalize("Model 1"), described_class.normalize("Model 1.0") ]
      )
    end

    it "represents blank metadata as absent" do
      expect(described_class.normalize("  \t\u00a0 ")).to be_nil
    end
  end

  describe ".call" do
    it "uses one comparison shape for catalog and seller values" do
      seller = described_class.call(name: " Câmera Canon EOS R6 ", brand: "CANON", category: "Photo")
      catalog = described_class.call(name: "Camera Canon EOS R6", brand: "Canon", category: "PHOTO")

      expect(seller).to eq(catalog)
    end
  end
end
