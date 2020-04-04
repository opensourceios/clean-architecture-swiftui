//
//  CountriesListTests.swift
//  UnitTests
//
//  Created by Alexey Naumov on 01.11.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import XCTest
import ViewInspector
import Combine
@testable import CountriesSwiftUI

extension CountriesList: Inspectable { }
extension ActivityIndicatorView: Inspectable { }
extension CountryCell: Inspectable { }
extension ErrorView: Inspectable { }

final class CountriesListTests: XCTestCase {
    
    func countriesListView(_ appState: AppState,
                           _ services: DIContainer.Services
    ) -> CountriesList {
        CountriesList(viewModel: CountriesList.ViewModel(
            container: DIContainer(appState: appState, services: services)))
    }

    func test_countries_notRequested() {
        let appState = AppState()
        XCTAssertEqual(appState.userData.countries, .notRequested)
        let services = DIContainer.Services.mocked(
            countriesService: [.loadCountries]
        )
        let sut = countriesListView(appState, services)
        let exp = sut.inspection.inspect { view in
            XCTAssertNoThrow(try view.content().text())
            services.verify()
        }
        ViewHosting.host(view: sut)
        wait(for: [exp], timeout: 2)
    }
    
    func test_countries_isLoading_initial() {
        var appState = AppState()
        let services = DIContainer.Services.mocked()
        appState.userData.countries = .isLoading(last: nil, cancelBag: CancelBag())
        let sut = countriesListView(appState, services)
        let exp = sut.inspection.inspect { view in
            let vStack = try view.content().vStack()
            XCTAssertNoThrow(try vStack.view(ActivityIndicatorView.self, 0))
            XCTAssertThrowsError(try vStack.list(1))
            services.verify()
        }
        ViewHosting.host(view: sut)
        wait(for: [exp], timeout: 2)
    }
    
    func test_countries_isLoading_refresh() {
        var appState = AppState()
        appState.userData.countries = .isLoading(last: Country.mockedData,
                                                 cancelBag: CancelBag())
        let services = DIContainer.Services.mocked()
        let sut = countriesListView(appState, services)
        let exp = sut.inspection.inspect { view in
            let vStack = try view.content().vStack()
            XCTAssertNoThrow(try vStack.view(ActivityIndicatorView.self, 0))
            let countries = try vStack.vStack(1)
            XCTAssertThrowsError(try countries.view(SearchBar.self, 0))
            XCTAssertNoThrow(try countries.list(1))
            services.verify()
        }
        ViewHosting.host(view: sut)
        wait(for: [exp], timeout: 2)
    }
    
    func test_countries_loaded() {
        var appState = AppState()
        appState.userData.countries = .loaded(Country.mockedData)
        let services = DIContainer.Services.mocked()
        let sut = countriesListView(appState, services)
        let exp = sut.inspection.inspect { view in
            XCTAssertNoThrow(try view.content().vStack().view(SearchBar.self, 0))
            let cell = try view.firstRowLink()
                .label().view(CountryCell.self).actualView()
            XCTAssertEqual(cell.country, Country.mockedData[0])
            services.verify()
        }
        ViewHosting.host(view: sut)
        wait(for: [exp], timeout: 2)
    }
    
    func test_countries_failed() {
        var appState = AppState()
        appState.userData.countries = .failed(NSError.test)
        let services = DIContainer.Services.mocked()
        let sut = countriesListView(appState, services)
        let exp = sut.inspection.inspect { view in
            XCTAssertNoThrow(try view.content().view(ErrorView.self))
            services.verify()
        }
        ViewHosting.host(view: sut)
        wait(for: [exp], timeout: 2)
    }
    
    func test_countries_failed_retry() {
        var appState = AppState()
        appState.userData.countries = .failed(NSError.test)
        let services = DIContainer.Services.mocked(
            countriesService: [.loadCountries]
        )
        let sut = countriesListView(appState, services)
        let exp = sut.inspection.inspect { view in
            let errorView = try view.content().view(ErrorView.self)
            try errorView.vStack().button(2).tap()
            services.verify()
        }
        ViewHosting.host(view: sut)
        wait(for: [exp], timeout: 2)
    }
    
    func test_countries_navigation_to_details() {
        let countries = Country.mockedData
        var appState = AppState()
        appState.userData.countries = .loaded(countries)
        let services = DIContainer.Services.mocked(
            countriesService: [.loadCountryDetails(countries[0])]
        )
        let sut = countriesListView(appState, services)
        let container = sut.viewModel.container
        XCTAssertNil(container.appState.value.routing.countriesList.countryDetails)
        let exp = sut.inspection.inspect { view in
            let firstCountryRow = try view.firstRowLink()
            try firstCountryRow.activate()
            let selected = container.appState.value.routing.countriesList.countryDetails
            XCTAssertEqual(selected, countries[0].alpha3Code)
            try firstCountryRow.view(CountryDetails.self).content().text().callOnAppear()
            services.verify()
        }
        ViewHosting.host(view: sut)
        wait(for: [exp], timeout: 2)
    }
}

final class LocalizationTests: XCTestCase {
    func test_country_localized_name() {
        let sut = Country(name: "Abc", translations: ["fr": "Xyz"], population: 0, flag: nil, alpha3Code: "")
        let locale = Locale(identifier: "fr")
        XCTAssertEqual(sut.name(locale: locale), "Xyz")
    }
    
    func test_string_for_locale() {
        let sut = "Countries".localized(Locale(identifier: "fr"))
        XCTAssertEqual(sut, "Des pays")
    }
}

final class CountriesListFilterTests: XCTestCase {
    
    func test_countries_filtering() {
        let publisher = ObservableObjectPublisher()
        var sut = CountriesList.ViewModel.CountriesSearch(searchResultsWillChange: publisher)
        let countries = Country.mockedData
        sut.all = .loaded(countries)
        XCTAssertEqual(sut.filtered.value, countries)
        sut.searchText = countries[0].name
        XCTAssertEqual(sut.filtered.value, [countries[0]])
    }
}

// MARK: - CountriesList inspection helper

extension InspectableView where View == ViewType.View<CountriesList> {
    func content() throws -> InspectableView<ViewType.AnyView> {
        return try geometryReader().navigationView().anyView(0)
    }
    func firstRowLink() throws -> InspectableView<ViewType.NavigationLink> {
        return try content().vStack().list(1).forEach(0).hStack(0).navigationLink(0)
    }
}
