require 'json'
require 'csv'

def upload_video(suburb)
   `
    curl \
      -F 'source=@#{suburb}.mp4' \
      -F 'access_token=#{ACCESS_TOKEN}' \
      https://graph-video.facebook.com/v3.1/#{ACCOUNT_ID}/advideos
  `
end

def thumbnails(video_id)
  `
    curl -G \
      -d 'access_token=#{ACCESS_TOKEN}' \
      https://graph.facebook.com/v3.1/#{video_id}/thumbnails
  `
end

def create_ad_creative(video_id, thumbnail_url)
  `
    curl \
      -F 'name=Sample Creative' \
      -F 'object_story_spec={
        "page_id": "#{PAGE_ID}",
        "video_data": {
          "call_to_action": {"type":"LIKE_PAGE","value":{"page":"#{PAGE_ID}"}},
          "image_url": "#{thumbnail_url}",
          "video_id": "#{video_id}"
        }
      }' \
      -F 'access_token=#{ACCESS_TOKEN}' \
      https://graph.facebook.com/v3.1/#{ACCOUNT_ID}/adcreatives
  `
end


def create_ad_set(location, zipcode)
  `
    curl \
      -F 'name=#{location}' \
      -F 'campaign_id=#{CAMPAIGN_ID}' \
      -F 'daily_budget=500' \
      -F 'billing_event=IMPRESSIONS' \
      -F 'optimization_goal=REACH' \
      -F 'bid_amount=100' \
      -F 'targeting={"geo_locations":{"zips":[{"key":"AU:#{zipcode}"}]}, "publisher_platforms":["facebook"]}' \
      -F 'status=PAUSED' \
      -F 'access_token=#{ACCESS_TOKEN}' \
      https://graph.facebook.com/v3.1/#{ACCOUNT_ID}/adsets
  `
end

def create_ad(suburb, ad_set_id, ad_creative_id)
  `
    curl -X POST \
    -F "name=#{suburb}" \
    -F "adset_id=#{ad_set_id}" \
    -F "creative={'creative_id':#{ad_creative_id}}" \
    -F "status=PAUSED" \
    -F 'access_token=#{ACCESS_TOKEN}' \
    "https://graph.facebook.com/v3.1/#{ACCOUNT_ID}/ads"
  `
end

def build(suburb, postcode)
  puts "Building Ads for #{suburb}"
  puts "Creating Ad Set"
  ad_set_response = create_ad_set(suburb, postcode)
  puts ad_set_response
  ad_set_id = JSON.parse(ad_set_response)["id"]


  puts "Uploading Video"
  video_upload_response = upload_video(suburb)
  puts video_upload_response
  video_id = JSON.parse(video_upload_response)["id"]

  thumbnail_response = nil
  loop do
    thumbnail_response = thumbnails(video_id)
    break if JSON.parse(thumbnail_response)["data"] != []
    puts thumbnail_response
    puts "Retrying to get thumbnails"
    sleep(5)
  end
  puts thumbnail_response
  thumbnail_url = JSON.parse(thumbnail_response)["data"].last["uri"]

  puts "Creating Ad Creative"
  ad_creative_response = create_ad_creative(
    video_id,
    thumbnail_url
  )
  puts ad_creative_response
  ad_creative_id = JSON.parse(ad_creative_response)["id"]

  puts "Creating Ad"
  response = create_ad(suburb, ad_set_id, ad_creative_id)

  puts JSON.parse(response)
end

CSV.foreach("config.csv", headers: true) do |config|
  CAMPAIGN_ID = config["campaign_id"]
  PAGE_ID = config["page_id"]
  ACCOUNT_ID = config["account_id"]
  ACCESS_TOKEN = config["access_token"]

  CSV.foreach("regions.csv", headers: true) do |row|
    build(
      row["suburb"],
      row["postcode"],
    )
  end
end
