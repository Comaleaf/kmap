#!/usr/bin/env ruby

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

# Convert k-map representation to sum of products representation
for row in 0...rows.length
	for col in 0...labels.length
		# Greycode is a binary representation where only one binary digit is ever changed for increments
		# This is used in k-map encodings as adjacdent cells must not change by more than 1 bit
		def greycode(n)
			(n >> 1) ^ n
		end

		# The encoding can be considered as a single binary word where the half of bits are the greycode representation
		# of the row, and the second half of the bits are the greycode representation of the column
		term = ((greycode(row) << labels.length/2) + greycode(col))
			.to_s(2)                   # Convert to binary representation (base 2)
			.rjust(labels.length, '0') # Pad with leading zeros for the number of inputs

		case rows[row][col]
			when "1"
				minterms << term
			when "X"
				dontcares << term
		end
	end
end

# Quine-McCluskey: first step, consolidate minterms into largest groups
def consolidate(minterms)
	# Returns a consolidated word, and the count of how many bits had to be changed to get it 
	def combine_words(a, b)
		count = 0
		word = a.each_char.zip(b.each_char).map {|c| if c[0] != c[1] then count += 1; '-' else c[0] end}
		return word.join, count
	end

	implicants = []

	# For each minterm
	for term in minterms
		combined = false

		# Attempt to combine with all other minterms
		for comparing_term in (minterms - [term])
			new_term, change_count = combine_words(term, comparing_term)

			if change_count == 1 then
				combined = true
				implicants << new_term
			end
		end

		# If no combination was succesful, the minterm must be added as an implicant as it cannot be combined further
		if combined == false then
			implicants << term
		end
	end

	# Only give distinct implicants
	return implicants.uniq
end

# For the purpose of minimisation we want to treat dontcares as minterms - they will then be removed later
prime_implicants = minterms + dontcares

# Iteratively consolidate implicants until no more combinations can be made
until (consolidate(prime_implicants) == prime_implicants) do
	prime_implicants = consolidate(prime_implicants)
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
