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

    it "keeps a brand-only difference in the identity" do
      first = described_class.call(name: "Camera R6", brand: "Canon", category: "Photo")
      second = described_class.call(name: "Camera R6", brand: "Nikon", category: "Photo")

      expect(first).not_to eq(second)
    end

    it "keeps a category-only difference in the identity" do
      first = described_class.call(name: "Camera R6", brand: "Canon", category: "Photo")
      second = described_class.call(name: "Camera R6", brand: "Canon", category: "Electronics")

      expect(first).not_to eq(second)
    end

    it "finds separately normalized equivalent identities as hash keys" do
      first = described_class.call(name: " Câmera R6 ", brand: "CANON", category: "Photo")
      second = described_class.call(name: "Camera R6", brand: "Canon", category: "PHOTO")

      expect({ first => :matched }[second]).to eq(:matched)
    end

    it "keeps its hash key stable after the caller changes input strings" do
      name = "Câmera R6"
      brand = "CANON"
      category = "Photo"
      identity = described_class.call(name: name, brand: brand, category: category)
      values = { identity => :matched }
      name.replace("changed")
      brand.replace("changed")
      category.replace("changed")

      expect(values[described_class.call(name: "Camera R6", brand: "Canon", category: "Photo")]).to eq(:matched)
    end

    it "does not expose mutable normalized values" do
      identity = described_class.call(name: "Camera R6", brand: "Canon", category: "Photo")

      expect([ identity.name.frozen?, identity.brand.frozen?, identity.category.frozen? ]).to eq([ true, true, true ])
    end
  end
end
