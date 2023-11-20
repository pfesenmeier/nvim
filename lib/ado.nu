# --include-links?
# --repositor 
def "pr list" [] {
  (
    run-external --redirect-std-out "az" "repos" "pr" "list" "--query"
      "[? .repository == "myrepo" && .status == 'active' ].{name: name, url: url}"
    | from json
    | each {|it|
        let clickable_url = $it.url
          
        update url $clickable_url 
      }
  )
}
