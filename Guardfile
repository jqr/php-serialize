guard(:minitest,
  all_on_start: false,
) do
  watch(%r{^test/test_helper\.rb$}) { "test" }
  watch(%r{^lib/(.+)\.(rb|js)$}) { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^test/.+_test\.rb$})
end
