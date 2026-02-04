.PHONY: deploy deploy-ios deploy-android build-ios build-android

deploy: deploy-ios deploy-android
	@echo "Deploy completo para iOS e Android!"

deploy-ios:
	@echo "Subindo para TestFlight..."
	cd ios && bundle exec fastlane beta

deploy-android:
	@echo "Subindo para Firebase App Distribution..."
	cd android && bundle exec fastlane distribute

build-ios:
	@echo "Buildando iOS..."
	cd ios && bundle exec fastlane build

build-android:
	@echo "Buildando Android..."
	cd android && bundle exec fastlane build
