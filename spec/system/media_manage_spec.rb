# frozen_string_literal: true

require 'rails_helper'
require 'google/apis/youtube_v3'

class YoutubeVideosInfo
  def initialize(title:, hour: 0, min: 0, sec: 0, item_count: 1)
    @title = title
    time = hour.hour + min.minutes + sec.seconds
    @duration = time.iso8601
    @item_count = item_count
  end

  def respond_to_missing?(sym, _include_private)
    list = [:items, :content_details, :snippet, :duration, :title]
    return true if list.include?(sym)

    nil
  end

  # 以下が通るように返す
  # YoutubeVideosInfo.items[0].content_details.duration
  # YoutubeVideosInfo.items[0].snippet.title
  def method_missing(method, *_args)
    if method == :items
      return [] if @item_count == 0

      return Array.new(@item_count, self)
    end

    return self if method == :content_details
    return self if method == :snippet
    return @duration if method == :duration
    return @title if method == :title
  end
end

RSpec.describe 'media_manage', type: :system, js: true do
  let(:alice) { create(:alice) }
  let!(:media_manage_other_site) { create(:media_manage_other_site, user_id: alice.id) }

  before do
    @youtube_service_moc = double('YouTubeService moc')
    allow(Google::Apis::YoutubeV3::YouTubeService).to receive(:new).and_return(@youtube_service_moc)
    allow(@youtube_service_moc).to receive('key=').and_return(->(api_key) {})

    visit root_path
    login(alice)
  end

  scenario '新規動画追加(その他のサイト)' do
    # 新規動画作成ページを表示
    toggle_side_nav
    within('#sidenav-menu') { click_link '新規動画' }
    expect(page).to have_content('編集')

    # 情報を入力
    find('.media_manage-edit-details').click
    title = '【テスト】動画タイトル'
    fill_in 'media_manage[title]', with: title
    fill_in 'media_manage[media_url]', with: 'https://www.example.com/watch?v=123456'
    fill_in 'length-time-input-hour', with: 1
    fill_in 'length-time-input-min', with: 2
    fill_in 'length-time-input-sec', with: 3
    click_on '更新'
    expect(page).to have_content('動画情報を更新しました')
    expect(page).to have_content(title)
    within('.media-manage-show__media-info') { expect(page).to have_content('01:02:03') }

    # 一覧
    toggle_side_nav
    within('#sidenav-menu') { click_link '動画一覧' }
    expect(page).to have_content(title)
    expect(page).to have_content('01:02:03') # 動画時間
    expect(page).to have_content('未視聴')
  end

  describe 'youtube' do
    before do
      # 新規動画作成ページを表示
      toggle_side_nav
      within('#sidenav-menu') { click_link '新規動画' }
      expect(page).to have_content('編集')

      # 情報を入力
      @title = '【テスト】youtubeタイトル'
      fill_in 'media_manage[media_url]', with: 'https://www.youtube.com/watch?v=123456'
    end

    scenario 'youtube情報取得' do
      allow(@youtube_service_moc).to receive(:list_videos).and_return(
        YoutubeVideosInfo.new(title: @title, hour: 4, min: 5, sec: 6)
      )
      click_on '更新'
      expect(page).to have_content('動画情報を更新しました')
      expect(page).to have_content('youtubeからの取得に成功しました。')
      expect(page).to have_content(@title)
      within('.media-manage-show__media-info') { expect(page).to have_content('04:05:06') }

      # youtube情報変化
      allow(@youtube_service_moc).to receive(:list_videos).and_return(
        YoutubeVideosInfo.new(title: 'newタイトル', hour: 3, min: 2, sec: 1)
      )
      click_link '動画情報更新'
      expect(page).to have_content('youtubeからの取得に成功しました。')
      expect(page).to have_content('newタイトル')
      within('.media-manage-show__media-info') { expect(page).to have_content('03:02:01') }
    end

    scenario 'youtube情報取得失敗(apiエラー)' do
      allow(@youtube_service_moc).to receive(:list_videos).and_raise(
        Google::Apis::ServerError, **{ message: 'ServerError message' }
      )
      click_on '更新'
      expect(page).to have_content('youtubeからの取得に失敗しました。')
    end

    scenario 'youtube情報取得(データエラー)' do
      allow(@youtube_service_moc).to receive(:list_videos).and_return(
        YoutubeVideosInfo.new(title: @title, hour: 4, min: 5, sec: 6, item_count: 2)
      )
      click_on '更新'
      expect(page).to have_content('youtubeからの取得に失敗しました。')
    end

    scenario 'spanの動画のリンクが続きからになっているか' do
      allow(@youtube_service_moc).to receive(:list_videos).and_return(
        YoutubeVideosInfo.new(title: @title, hour: 4, min: 5, sec: 6, item_count: 2)
      )
      click_on '更新'
      click_on '時間追加'
      fill_in_time('begin', hour: 0, min: 0, sec: 0)
      fill_in_time('end', hour: 1, min: 0, sec: 0)
      click_on '登録'
      expect(find_all('#time-span-block-0 a')[0][:href]).to eq 'https://www.youtube.com/watch?v=123456&t=3600'
    end
  end

  context '変更系' do
    before do
      toggle_side_nav
      within('#sidenav-menu') { click_link '動画一覧' }
      expect(page).to have_content(media_manage_other_site.title)
      click_link media_manage_other_site.title
    end

    scenario 'タイトル変更' do
      click_link '編集'
      find('.media_manage-edit-details').click
      new_title = 'newタイトル'
      fill_in 'media_manage[title]', with: new_title
      fill_in 'length-time-input-hour', with: 12
      fill_in 'length-time-input-min', with: 45
      fill_in 'length-time-input-sec', with: 56
      click_on '更新'
      expect(page).to have_content('動画情報を更新しました')
      expect(page).to have_content(new_title)
      within('.media-manage-show__media-info') { expect(page).to have_content('12:45:56') }
    end

    scenario '編集-キャンセル' do
      click_link '編集'
      find('.media_manage-edit-details').click
      new_title = 'newタイトル'
      fill_in 'media_manage[title]', with: new_title
      fill_in 'length-time-input-hour', with: 12
      fill_in 'length-time-input-min', with: 45
      fill_in 'length-time-input-sec', with: 56
      click_on 'キャンセル'
      expect(page).to have_content(media_manage_other_site.title)
      within('.media-manage-show__media-info') { expect(page).to have_content('01:02:03') }
    end

    scenario '削除' do
      click_link '編集'
      click_on 'delete' # 表示はDELETE
      expect(page).to have_content('確認')
      click_on '削除する'
      expect(page).to have_content('動画情報を削除しました')
      expect(page).to_not have_content(media_manage_other_site.title)
    end

    scenario '削除-キャンセル' do
      click_link '編集'
      click_on 'delete' # 表示はDELETE
      expect(page).to have_content('確認')
      within('.modaal-content-container') { click_on 'キャンセル' }
      expect(page).to have_content('編集')
    end

    scenario '視聴時間入力' do
      click_on '時間追加'
      fill_in_time('begin', hour: 1, min: 2, sec: 3)
      fill_in_time('end', hour: 4, min: 5, sec: 6)
      click_on '登録'

      within('.waching-data-section') do
        expect(page).to have_content('01:02:03')
        expect(page).to have_content('04:05:06')
      end
    end

    scenario '視聴ステータス' do
      # 途中までの時間で入力
      click_on '時間追加'
      fill_in_time('begin', hour: 0, min: 0, sec: 0)
      fill_in_time('end', hour: 0, min: 1, sec: 2)
      click_on '登録'

      click_link '一覧に戻る'
      within('.media-manage__card-info-status') do
        expect(page).to have_content('視聴中・のこり01:01:01')
      end

      # 動画が見終わるように入力
      click_link media_manage_other_site.title
      click_on '時間追加'
      fill_in_time('begin', hour: 0, min: 0, sec: 0)
      fill_in_time('end', hour: 1, min: 2, sec: 3)
      click_on '登録'

      click_link '一覧に戻る'
      find('label', text: '視聴済み').click
      click_on '検索'
      within('.media-manage__card-info-status') do
        expect(page).to have_content('視聴済み')
      end
    end

    scenario '視聴時間入力(キャンセル)' do
      click_on '時間追加'
      fill_in_time('begin', hour: 3, min: 2, sec: 1)
      fill_in_time('end', hour: 4, min: 5, sec: 6)
      click_on 'キャンセル'

      within('.waching-data-section') do
        expect(page).to_not have_content('03:02:01')
        expect(page).to_not have_content('04:05:06')
      end
    end

    scenario '空欄時0として扱われること' do
      click_on '時間追加'
      fill_in_time('end', sec: 1)
      click_on '登録'

      within('.waching-data-section') do
        expect(page).to have_content('00:00:00')
        expect(page).to have_content('00:00:01')
      end
    end

    scenario '時間の削除' do
      click_on '時間追加'
      fill_in_time('end', hour: 1)
      click_on '登録'

      click_on '時間追加'
      fill_in_time('begin', hour: 2)
      fill_in_time('end', hour: 3)
      click_on '登録'

      within('.waching-data-section') do
        expect(page).to have_content('00:00:00')
        expect(page).to have_content('01:00:00')
        expect(page).to have_content('02:00:00')
        expect(page).to have_content('03:00:00')
      end

      find('#time-span-block-0').find('.time-span-delete').click

      within('.waching-data-section') do
        expect(page).to_not have_content('00:00:00')
        expect(page).to_not have_content('01:00:00')
        expect(page).to have_content('02:00:00')
        expect(page).to have_content('03:00:00')
      end
    end

    scenario '一つ前に戻る' do
      # 区間A
      click_on '時間追加'
      fill_in_time('end', hour: 2)
      click_on '登録'

      # まだ戻すボタンがないことを確認
      expect(page).to_not have_content('元に戻す')

      # 区間B
      click_on '時間追加'
      fill_in_time('begin', hour: 1)
      fill_in_time('end', hour: 3)
      click_on '登録'

      # マージされていることを確認
      within('.waching-data-section') do
        expect(page).to have_content('00:00:00')
        expect(page).to have_content('03:00:00')
      end

      # 戻すボタンが現れたことを確認
      expect(page).to have_content('元に戻す')

      # 戻す
      click_on '元に戻す'
      expect(page).to have_content('確認')
      click_on '戻す'

      expect(page).to have_content('元に戻しました')

      within('.waching-data-section') do
        expect(page).to have_content('00:00:00')
        expect(page).to have_content('02:00:00')
        expect(page).to_not have_content('03:00:00')
      end

      # 戻すボタン消えたことを確認
      expect(page).to_not have_content('元に戻す')
    end

    scenario '視聴完了にする' do
      within('.waching-data-section') do
        expect(page).to_not have_content('00:00:00')
        expect(page).to_not have_content('01:02:03')
      end

      click_on '視聴完了にする'
      click_on '視聴を完了する'

      within('.waching-data-section') do
        expect(page).to have_content('00:00:00')
        expect(page).to have_content('01:02:03')
      end
    end

    scenario '今は見ない' do
      expect(page).to have_content('今は見ない')
      expect(page).to have_content('に入れる')
      click_on '今は見ない'
      expect(page).to have_content('今は見ない')
      expect(page).to have_content('から削除する')
      click_on '今は見ない'
      expect(page).to have_content('今は見ない')
      expect(page).to have_content('に入れる')
    end
  end
end
