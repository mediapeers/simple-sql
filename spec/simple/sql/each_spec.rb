require "spec_helper"

describe "Simple::SQL.each" do
  context "when called without a block " do
    it "raises an ArgumentError" do
      expect {
        SQL.each("SELECT id FROM users", into: Hash)
      }.to raise_error(ArgumentError)
    end
  end

  def generate_users!
    1.upto(USER_COUNT).map { create(:user) }
  end
  
  def each!(sql, into: nil)
    @received = nil
    SQL.each(sql, into: into) do |id|
      @received ||= []
      @received << id
    end
  end

  let(:received) { @received }

  describe "each into: nil" do
    before { generate_users! }
    context "when called with matches" do
      it "receives rows as arrays" do
        each! "SELECT id, id FROM users ORDER BY id"

        expect(received).to eq(1.upto(USER_COUNT).map { |i| [ i,i ]})
      end

      it "receives single item row as individual objects" do
        each! "SELECT id FROM users ORDER BY id"

        expect(received).to eq(1.upto(USER_COUNT).to_a)
      end
    end

    context 'when called with no matches' do
      it "does not yield" do
        each! "SELECT id FROM users WHERE FALSE"
        expect(received).to be_nil
      end
    end
  end
  
  describe "each into: <something>" do
    before { generate_users! }

    it "receives rows as Hashes" do
      each! "SELECT id, id AS dupe FROM users ORDER BY id", into: Hash

      expect(received).to eq(1.upto(USER_COUNT).map { |i| { id: i, dupe: i }})
    end

    it "receives rows as immutable" do
      each! "SELECT id, id AS dupe FROM users ORDER BY id", into: :immutable

      expect(received.first.id).to eq(1)
      expect(received[1].dupe).to eq(2)
      expect(received.map(&:class).uniq).to eq([Simple::SQL::Helpers::Immutable])
    end
  end
  
  xdescribe "memory usage: pending due to inconclusive results" do
    it "generates a series" do
      each! "SELECT a.n from generate_series(1, 100) as a(n)"
      expect(received).to eq((1..100).to_a)
    end

    require 'memory_profiler'
    
    def measure_retained_objects(msg, &block)
      r = nil
      report = MemoryProfiler.report do
        r = yield
      end
      
      STDERR.puts "#{msg} Total allocated: #{report.total_allocated_memsize} bytes (#{report.total_allocated} objects)"
      STDERR.puts "#{msg} Total retained:  #{report.total_retained_memsize} bytes (#{report.total_retained} objects)"

      report.total_retained_memsize
    end

    it "is using less memory than .all" do
      sql_warmup = "SELECT a.n from generate_series(10000, 100) as a(n)"

        SQL.all(sql_warmup, into: Hash)

        SQL.each(sql_warmup) do |id|
          :nop
        end

      cnt = 1000000
      sql = "SELECT a.n from generate_series(#{cnt}, #{cnt}) as a(n)"

      r = nil
      retained_objects_all = measure_retained_objects "all" do
        r = SQL.all(sql, into: Hash)
      end

      retained_objects_each = measure_retained_objects "each"  do
        r = SQL.each(sql) do |id|
          :nop
        end
      end
      
      expect(0).to eq "one"
    end
  end
end

__END__

  describe "each into: X" do
    it "calls the database" do
      r = SQL.all("SELECT id FROM users", into: Hash)
      expect(r).to be_a(Array)
      expect(r.length).to eq(USER_COUNT)
      expect(r.map(&:class).uniq).to eq([Hash])
    end

    it "returns an empty array when there is no match" do
      r = SQL.all("SELECT * FROM users WHERE FALSE", into: Hash)
      expect(r).to eq([])
    end

    it "yields the results into a block" do
      received = []
      SQL.all("SELECT id FROM users", into: Hash) do |hsh|
        received << hsh
      end
      expect(received.length).to eq(USER_COUNT)
      expect(received.map(&:class).uniq).to eq([Hash])
    end

    it "does not yield if there is no match" do
      received = []
      SQL.all("SELECT id FROM users WHERE FALSE", into: Hash) do |hsh|
        received << hsh
      end
      expect(received.length).to eq(0)
    end
  end
end
