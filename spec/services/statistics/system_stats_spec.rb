describe Sufia::Statistics::SystemStats do
  let(:user1) { create(:user) }
  let(:start_date) { nil }
  let(:end_date) { nil }
  let(:stats) { described_class.new(depositor_count, start_date, end_date) }

  describe "#top_depositors" do
    context "when requested count is withing bounds" do
      let!(:user2) { create(:user) }
      let(:depositor_count) { 15 }

      # I am specifically creating objects in this test
      # I am doing this for one test to make sure that the full loop works
      before do
        GenericWork.new(id: "abc123") do |gf|
          gf.apply_depositor_metadata(user1)
          gf.update_index
        end
        GenericWork.new(id: "def123") do |gf|
          gf.apply_depositor_metadata(user2)
          gf.update_index
        end
        GenericWork.new(id: "zzz123") do |gf|
          gf.create_date = [2.days.ago]
          gf.apply_depositor_metadata(user1)
          gf.update_index
        end
        GenericWork.new(id: "ccc123") do |c|
          c.apply_depositor_metadata(user1)
          c.update_index
        end
      end

      it "queries for the data" do
        expect(stats.top_depositors).to eq(user1.user_key => 3, user2.user_key => 1)
      end
    end

    context "when requested count is too small" do
      let(:depositor_count) { 3 }
      let(:actual_count) { 5 }

      it "queries for 5 items" do
        expect(stats.limit).to eq actual_count
      end
    end

    context "when requested count is too big" do
      let(:depositor_count) { 99 }
      let(:actual_count) { 20 }

      it "queries for 20 items" do
        expect(stats.limit).to eq actual_count
      end
    end
  end

  describe "#top_formats" do
    let(:depositor_count) { nil }
    let(:pdf_file_set) do
      build(:public_pdf, user: user1, id: "pdf1111")
    end
    let(:wav_file_set) do
      build(:public_wav, user: user1, id: "wav1111")
    end
    let(:mp3_file_set) do
      build(:public_mp3, user: user1, id: "mp31111", create_date: [2.days.ago])
    end
    let(:doc_file_set) do
      build(:file_set, :registered, user: user1, id: "word1111")
    end

    before do
      allow(pdf_file_set).to receive(:mime_type) { 'application/pdf' }
      allow(wav_file_set).to receive(:mime_type) { 'audio/wav' }
      allow(mp3_file_set).to receive(:mime_type) { 'audio/mpeg' }
      allow(doc_file_set).to receive(:mime_type) { 'application/vnd.ms-word.document' }
      pdf_file_set.update_index
      wav_file_set.update_index
      mp3_file_set.update_index
      doc_file_set.update_index
    end

    subject { stats.top_formats }

    it { is_expected.to include("mpeg" => 1, "pdf" => 1, "wav" => 1, "vnd.ms-word.document" => 1) }

    context "when more than 5 formats available" do
      let(:pdf_file_set2) do
        build(:public_pdf, user: user1, id: "pdf2222")
      end
      let(:wav_file_set2) do
        build(:public_wav, user: user1, id: "wav2222")
      end
      let(:mp3_file_set2) do
        build(:public_mp3, user: user1, id: "mp32222", create_date: [2.days.ago])
      end
      let(:doc_file_set2) do
        build(:file_set, :registered, user: user1, id: "reg2222")
      end
      let(:png_file_set1) do
        build(:file_set, user: user1, id: "png1111")
      end
      let(:png_file_set2) do
        build(:file_set, user: user1, id: "png2222")
      end
      let(:jpg_file_set) do
        build(:file_set, user: user1, id: "jpeg2222")
      end

      before do
        allow(pdf_file_set2).to receive(:mime_type) { 'application/pdf' }
        allow(wav_file_set2).to receive(:mime_type) { 'audio/wav' }
        allow(mp3_file_set2).to receive(:mime_type) { 'audio/mpeg' }
        allow(doc_file_set2).to receive(:mime_type) { 'application/vnd.ms-word.document' }
        allow(png_file_set1).to receive(:mime_type) { 'image/png' }
        allow(png_file_set2).to receive(:mime_type) { 'image/png' }
        allow(jpg_file_set).to receive(:mime_type) { 'image/jpeg' }
        pdf_file_set2.update_index
        wav_file_set2.update_index
        mp3_file_set2.update_index
        doc_file_set2.update_index
        png_file_set1.update_index
        png_file_set2.update_index
        jpg_file_set.update_index
      end

      it do
        is_expected.to include("mpeg" => 2, "pdf" => 2, "wav" => 2, "vnd.ms-word.document" => 2, "png" => 2)
        is_expected.not_to include("jpeg" => 1)
      end
    end
  end

  describe "#recent_users" do
    let!(:user2) { create(:user) }

    let(:two_days_ago_date) { 2.days.ago.beginning_of_day }
    let(:one_day_ago_date) { 1.day.ago.end_of_day }

    let(:depositor_count) { nil }

    subject { stats.recent_users }

    context "without dates" do
      let(:mock_order) { double }
      let(:mock_limit) { double }
      it "defaults to latest 5 users" do
        expect(mock_order).to receive(:limit).with(5).and_return(mock_limit)
        expect(User).to receive(:order).with('created_at DESC').and_return(mock_order)
        is_expected.to eq mock_limit
      end
    end

    context "with start date" do
      let(:start_date) { two_days_ago_date }

      it "allows queries  without an end date " do
        expect(User).to receive(:recent_users).with(two_days_ago_date, nil).and_return([user2])
        is_expected.to eq([user2])
      end
    end
    context "with start date and end date" do
      let(:start_date) { two_days_ago_date }
      let(:end_date) { one_day_ago_date }
      it "queries" do
        expect(User).to receive(:recent_users).with(two_days_ago_date, one_day_ago_date).and_return([user2])
        is_expected.to eq([user2])
      end
    end
  end

  describe "#users_count" do
    let(:depositor_count) { nil }
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }

    subject { stats.users_count }

    it { is_expected.to eq 2 }
  end
end
