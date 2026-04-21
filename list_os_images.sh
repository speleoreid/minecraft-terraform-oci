oci compute image list \
  --compartment-id "ocid1.tenancy.oc1..aaaaaaaafelouqwek5cwfuxu3ojjrpv44sys65ffzqk5h4nd7pxssauehjza" \
  --region "us-phoenix-1" \
  --query "data[?contains(\"display-name\", 'Ubuntu') && contains(\"display-name\", 'aarch64')].{id:id, name:\"display-name\", created:\"time-created\"}" \
  --all --output table | sort -rk3 | head -20