/^# [0-9][0-9]* /{
	file = $3;

	gsub(/^"/, "", file);
	gsub(/"$/, "", file);

	while(gsub(/\/[^\/]*\/\.\.\//, "/", file)) {}

	destfile = file;
	if (!gsub(/^.*\/gcc\/.*\/include\//, "gcc/", destfile)) {
		if (!gsub(/^.*\/include\//, "", destfile)) {
			if (!gsub(/^.*\/include-fixed\//, "fix/", destfile)) {
				next
			}
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
