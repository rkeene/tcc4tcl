/^# [0-9][0-9]* /{
	file = $3;

	gsub(/^"/, "", file);
	gsub(/"$/, "", file);

	destfile = file;
	if (!gsub(/^.*\/include\//, "", destfile)) {
		if (!gsub(/^.*\/include-fixed\//, "", destfile)) {
			next
		}
	}

	if (file ~ /</) {
		next;
	}

	if (file !~ /\.h$/) {
		next;
	}

	copy[file] = destfile;
}

END{
	for (key in copy) {
		print key, copy[key];
	}
}
