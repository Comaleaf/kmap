#!/usr/bin/env ruby

####################################################################################
####################################################################################
#
# Karnaugh-Map Minimiser
# @author Lauren Tomasello <lt696@york.ac.uk>
#
# Takes a karnaugh map representation of a digital logic design and uses the 
# Quine-McCluskey algorithm to produce a minimised sum-of-products form of the
# design.
#
# Example, k-map for function F that takes 4-inputs, ABCD:
#
#      F       [CD]
#        \   00 01 11 10
#          +------------
#       00 | 0  0  0  0
#  [AB] 01 | 1  0  0  0
#       11 | 1  0  1  X
#       10 | 1  X  1  1
#
#  Input the labels as the first argument, then each row as each successive
#  argument
#
#  % ./kmap.rb ABCD 0000 1000 101X 1X11
#  B!C!D + AC + A!D
#
####################################################################################
####################################################################################

####################################################################################
#
# Step 1: Take and validate input
#

labels = []
rows   = []

abort("Must specify arguments") unless ARGV.length > 0

# Labels seem fine
labels = ARGV[0].split(//)

abort("Labels must be unique")                  unless labels.uniq.length == labels.length
abort("Column count does not match row length") unless (ARGV.length - 1) == ARGV[0].length

# Rows seem fine
rows = ARGV.drop(1).map {|r| r.upcase.split(//)}

####################################################################################
#
# Step 2: Convert the Karnaugh Map to a Sum-of-Products for use with Quine-McCluskey
#
minterms  = []
dontcares = []

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
			when "1" then minterms << term
			when "X" then dontcares << term
		end
	end
end


####################################################################################
#
# Step 3: Find the prime implicants of the minterms (the smallest number of literals that
# can express each group of minterms)
#

# Returns an array of minterms where all minterms that changed by a single bit have been
# consolidated into one minterm.
def consolidate(minterms)
	# Returns a consolidated word, and the count of how many bits had to be changed to get it 
	def combine_words(a, b)
		count = 0
		
		return a.chars.zip(b.chars).map do |c|
			if c[0] != c[1] then
				count += 1
				'-'
			else
				c[0]
			end
		end.join, count
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

final_implicants              = []
minterms_matched_by_implicant = {}
implicants_for_minterm        = {}

####################################################################################
#
# Step 4: Build a prime implicant table, which is used to find essential prime implicants
#

# Build table of minterms matched by implicants, and find essential prime implicants
for minterm in minterms
	# A term is satisfied by an implicant if all their characters match or are ignored 
	def satisfied_by(term, implicant) 
		term.chars.each_with_index.map do |c, i|
			c == implicant[i] or implicant[i] == '-'
		end.all?
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
			terms.each {|term| implicants_for_minterm[term] -= [implicant]}
			minterms_matched_by_implicant[implicant] -= terms
			minterms_matched_by_implicant[implicant].length > 0 # Only retain implicants that still match minterms
		end
	end
end

# Iteratively find the implicant that covers the most minterms and work on down until there are no minterms left
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

####################################################################################
#
# Step 5: Convert the final array of essential prime implicants into an algebraic representation of
# sum-of-products.
#

# Gives a product term from an implicant
product_term = lambda do |term|
	term.chars.each_with_index.map do |c, i|
		case c
			when "0" then "!" << labels[i]
			when "1" then labels[i]
		end
	end.join
end

# Join the array of product terms around the + to make a sum-of-products
puts final_implicants.uniq.map(&product_term).join(" + ")
