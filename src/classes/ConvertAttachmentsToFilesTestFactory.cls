/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Utility for creating test data.
 * Note, non @isTest methods in a test class will yield
 * inaccurate code coverage metrics, that is why this class exists.
 * This class gets code coverage by being leveraged directly in test classes.
 *
 * https://help.salesforce.com/articleView?id=Why-is-a-Test-class-evaluated-as-part-of-the-Organization-s-Code-Coverage&language=en_US&type=1
 */
public with sharing class ConvertAttachmentsToFilesTestFactory {

    public static User newUser( ID profileId, String firstName, String lastName, String email ) {
        return newUser( profileId, null, firstName, lastName, email );
    }

    public static User newUser( ID profileId, ID roleId, String firstName, String lastName, String email ) {
        Integer rand = Math.round( Math.random() * 1000 );
        return new User(
            isActive = true,
            profileId = profileId,
            userRoleId = roleId,
            alias = firstName.substring(0,1) + lastName.substring(1,5),
            firstName = firstName,
            lastName = lastName,
            email = email,
            username = rand + email,
            emailEncodingKey = 'UTF-8',
            languageLocaleKey = 'en_US',
            localeSidKey = 'en_US',
            timeZoneSidKey = 'America/Chicago'
        );
    }

}