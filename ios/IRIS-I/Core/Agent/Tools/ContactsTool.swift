//
//  ContactsTool.swift
//  IRIS-I
//
//  On-device Contacts tool querying Apple Contacts framework (CNContactStore).
//  Enables contact search, name disambiguation, and phone/email lookup.
//

import Foundation
import Contacts

public struct ContactsTool: IRISAgentTool {
    public let name = "ContactsTool"
    public let description = "Searches and retrieves contact details (phone numbers, emails) from Apple Contacts."
    public let category = "communication"
    public let permissionLevel = PermissionLevel.protectedLevel

    public let parametersSchema = ToolParameterSchema(
        type: "object",
        properties: [
            "action": ToolPropertySchema(
                type: "string",
                description: "Operation: 'search_contacts' or 'get_contact_details'",
                enumValues: ["search_contacts", "get_contact_details"]
            ),
            "query": ToolPropertySchema(
                type: "string",
                description: "Name or keyword of the contact to find"
            )
        ],
        required: ["action", "query"]
    )

    private let store: CNContactStore

    public init(store: CNContactStore = CNContactStore()) {
        self.store = store
    }

    public func operationType(for arguments: [String: Any]) -> ActionOperationType {
        return .read
    }

    public func execute(arguments: [String: Any]) async -> AgentExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let query = (arguments["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !query.isEmpty else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Missing required 'query' argument.",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        // Check authorization
        let authorized = await requestAccess()
        guard authorized else {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Contacts access denied. Please enable Contacts in iOS Settings to search your contacts.",
                outcome: .deniedPolicy,
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }

        do {
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]

            let predicate = CNContact.predicateForContacts(matchingName: query)
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            if contacts.isEmpty {
                return AgentExecutionResult.success(
                    tool: name,
                    verified: true,
                    payload: [
                        "matches_count": "0",
                        "query": query,
                        "message": "No contacts found matching '\(query)'."
                    ],
                    durationMs: duration
                )
            }

            var contactSummaries: [[String: String]] = []
            for c in contacts.prefix(5) {
                let fullName = "\(c.givenName) \(c.familyName)".trimmingCharacters(in: .whitespaces)
                let phones = c.phoneNumbers.map { $0.value.stringValue }.joined(separator: ", ")
                let emails = c.emailAddresses.map { String($0.value) }.joined(separator: ", ")

                var item: [String: String] = [
                    "name": fullName.isEmpty ? c.organizationName : fullName,
                    "phones": phones,
                    "emails": emails
                ]
                if !c.organizationName.isEmpty {
                    item["organization"] = c.organizationName
                }
                contactSummaries.append(item)
            }

            let primary = contactSummaries[0]
            let desc = contacts.count == 1
                ? "Found \(primary["name"] ?? query): \(primary["phones"] ?? "No phone")"
                : "Found \(contacts.count) contacts matching '\(query)': \(contactSummaries.map { $0["name"] ?? "" }.joined(separator: ", "))"

            var outputPayload: [String: Sendable] = [
                "matches_count": "\(contacts.count)",
                "query": query,
                "message": desc,
                "primary_name": primary["name"] ?? query,
                "primary_phone": primary["phones"]?.components(separatedBy: ", ").first ?? ""
            ]

            return AgentExecutionResult.success(
                tool: name,
                verified: true,
                payload: outputPayload,
                durationMs: duration
            )
        } catch {
            return AgentExecutionResult.failure(
                tool: name,
                error: "Failed to query contacts: \(error.localizedDescription)",
                durationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            )
        }
    }

    private func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

