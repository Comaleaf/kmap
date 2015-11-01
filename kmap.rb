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

final_implicants = []
minterms_matched_by_implicant = {}
implicants_for_minterm = {}

# Build table of minterms matched by implicants, and find essential prime implicants
for minterm in minterms
	# A term is satisfied by an implicant if all their characters match or are ignored 
	def satisfied_by(term, implicant) 
		(term.each_char.each_with_index.map {|c, i| c == implicant[i] or implicant[i] == '-'}).all?
	end

	for implicant in prime_implicants
		implicants_for_minterm[minterm] ||= []
		minterms_matched_by_implicant[implicant] ||= []

		# If an implicant satisfies a term, put it into the prime implicant chart
		if satisfied_by(minterm, implicant) then
			implicants_for_minterm[minterm] << implicant
			minterms_matched_by_implicant[implicant] << minterm
		end
	end
end

# Remove essential prime implicants first as they will need to be removed anyway
minterms.each do |minterm|
	if implicants_for_minterm[minterm].length == 1 then
		# This is an essential prime implicant, as it is the only implicant for a particular minterm
		final_implicants << implicants_for_minterm[minterm].first
		
		# Remove any minterms matched by this implicant from the list of minterms remaining
		terms = minterms_matched_by_implicant[final_implicants.last]
		minterms -= terms
		minterms_matched_by_implicant.select! do |implicant, _|
			minterms_matched_by_implicant[implicant] -= terms
			minterms_matched_by_implicant[implicant].length > 0 # Only retain implicants that still match minterms
		end
	end
end

while minterms.length > 0 do
	# Keep finding the biggest implicant, then remove it and the minterms it covers and try next
	implicant, terms = minterms_matched_by_implicant.max_by {|minterms| minterms.length}

	# Use this one
	final_implicants << implicant

	# Clear up implicant and terms covered by it
	minterms -= terms

	minterms_matched_by_implicant.select! do |implicant, _|
		minterms_matched_by_implicant[implicant] -= terms
		minterms_matched_by_implicant[implicant].length > 0
	end
end

# Convert to sum-of-products representation
product_term = lambda do |term|
	term.each_char.each_with_index.map do |c, i|
		if c == "0" then
			"!" << labels[i]
		elsif c == "1" then
			labels[i]
		end
	end.join
end

puts final_implicants.uniq.map(&product_term).join(" + ")
