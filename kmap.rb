#!/usr/bin/env ruby

def binary_to_kmap_index(x, num_variables)
	# (n >> 1) ^ n gives the greycode equivalent representation of a number
	def greycode(n)
		return (n >> 1) ^ n
	end

	# this is used within the rows/columns of a kmap as only one term changes with an adjacent cell

	col = x % num_variables # Index of column in kmap
	row = x / num_variables # Index of row

	(greycode(row) << num_variables/2) + greycode(col)
end

def binary_string(n, size)
	output = ""
	while (size -= 1) >= 0 do 
		if (2 ** size) <= n then
			output << "1"
			n -= 2 ** size
		else
			output << "0"
		end 
	end
	return output
end

labels = []
rows = []
minterms = []
dontcares = []

# Input and validate args
abort("Must specify arguments") unless ARGV.length > 0

labels = ARGV[0].split(//)
abort("Labels must be unique") unless labels.uniq.length == labels.length

abort("Column count does not match row length") unless (ARGV.length - 1) == ARGV[0].length
rows = ARGV.drop(1).map {|r| r.upcase.split(//)}

# Find minterms and dontcares
width = labels.length
for i in (0...(width*width))
	term = rows[i / width][i % width]
	if term == "1"
		minterms << binary_string(binary_to_kmap_index(i, width), width) # Kmaps use greycode indexing as only one variable changes per adjacent cell
	elsif term == "X"
		dontcares << binary_string(binary_to_kmap_index(i, width), width) 
	end
end 

# Consolidate minterms
def consolidate(minterms)
	def changes(a, b)
		change_count = 0
		word = ""

		for i in (0...a.length)
			if a[i] != b[i] then
				change_count += 1
				word[i] = '-'
			else
				word[i] = a[i]
			end
		end

		return word, change_count
	end

	implicants = []

	for term in minterms
		combined = false

		for comparing_term in (minterms - [term])
			new_term, change_count = changes(term, comparing_term)
			if change_count == 1 then
				combined = true
				implicants << new_term
			end
		end

		if combined == false then
			implicants << term
		end
	end

	return implicants.uniq
end

prime_implicants = minterms + dontcares
new_implicants = []

# Iteratively consolidate implicants until we are left with the prime implicants
while (new_implicants = consolidate(prime_implicants)) != prime_implicants do
	prime_implicants = new_implicants
end

# Find essential prime implicants
def test(term, implicant) 
	for i in (0...term.length)
		if term[i] != implicant[i] and implicant[i] != '-' then
			return false
		end
	end

	return true
end

essential_prime_implicants = []
minterms_matched_by_implicant = {}
implicants_for_minterm = {}

# Build table of minterms matched by implicants, and find essential prime implicants
for minterm in minterms
	implicants_for_minterm[minterm] = []

	for implicant in prime_implicants
		minterms_matched_by_implicant[implicant] = [] unless minterms_matched_by_implicant[implicant].kind_of? Array

		if test(minterm, implicant) then
			implicants_for_minterm[minterm] << implicant
			minterms_matched_by_implicant[implicant] << minterm
		end
	end
end

# Remove essentials
for minterm in minterms
	# Skip minterms that have already been deleted
	if not minterms.member? minterm then next end

	if implicants_for_minterm[minterm].length == 1 then
		newly_covered_minterms = minterms_matched_by_implicant[implicants_for_minterm[minterm][0]]
		essential_prime_implicants << implicants_for_minterm[minterm][0]
		minterms -= newly_covered_minterms
		minterms_matched_by_implicant.select! {|implicant, minterms| minterms_matched_by_implicant[implicant] -= newly_covered_minterms; minterms_matched_by_implicant[implicant].length > 0}
	end
end

while minterms.length > 0 do
	# Keep finding the biggest implicant, then remove it and the minterms it covers and try next
	biggest_implicant = ""
	biggest_implicant_size = 0

	minterms_matched_by_implicant.each do |implicant, l_minterms|
		if l_minterms.length > biggest_implicant_size then
			biggest_implicant = implicant
			biggest_implicant_size = l_minterms.length
		end
	end

	# Use this one
	essential_prime_implicants << biggest_implicant

	# Clear up implicant and terms covered by it
	newly_covered_minterms = minterms_matched_by_implicant[biggest_implicant]
	minterms -= newly_covered_minterms

	minterms_matched_by_implicant.select! {|implicant, minterms| minterms_matched_by_implicant[implicant] -= newly_covered_minterms; minterms_matched_by_implicant[implicant].length > 0}
end

# Convert to sum-of-products representation
product_term = lambda do |t|
	output = ""

	for i in (0...t.length)
		if t[i] == "0" then
			output << "!" << labels[i]
		elsif t[i] == "1" then
			output << labels[i]
		end
	end

	return output
end

puts essential_prime_implicants.uniq.map(&product_term).join(" + ")
