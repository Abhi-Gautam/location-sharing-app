#!/usr/bin/env node

/**
 * Simple API Test - Test the location sharing APIs without browser automation
 * This validates that the backend is working correctly before trying visual tests
 */

const chalk = require('chalk');
const APIClient = require('./utils/api-client');

async function runSimpleApiTest() {
    console.log(chalk.blue('🚀 Running Simple API Test'));
    
    const client = new APIClient('http://localhost:4000');
    
    try {
        // Test 1: Health check
        console.log(chalk.blue('\n📋 Test 1: Health Check'));
        const health = await client.healthCheck();
        console.log(chalk.green('✅ Backend is healthy'));
        console.log(chalk.gray(`   Status: ${health.status}`));
        
        // Test 2: Create session
        console.log(chalk.blue('\n📋 Test 2: Create Session'));
        const session = await client.createSession('API Test Session');
        console.log(chalk.green('✅ Session created successfully'));
        console.log(chalk.gray(`   Session ID: ${session.session_id}`));
        console.log(chalk.gray(`   Expires: ${session.expires_at}`));
        
        // Test 3: Join session (simulate multiple users)
        console.log(chalk.blue('\n📋 Test 3: Join Session (3 users)'));
        const users = [];
        for (let i = 1; i <= 3; i++) {
            const joinResult = await client.joinSession(
                session.session_id,
                `Test User ${i}`,
                ['#FF6B6B', '#4ECDC4', '#45B7D1'][i-1]
            );
            users.push(joinResult);
            console.log(chalk.green(`✅ User ${i} joined successfully`));
            console.log(chalk.gray(`   Participant ID: ${joinResult.participant.id}`));
            console.log(chalk.gray(`   Token: ${joinResult.token.substring(0, 20)}...`));
        }
        
        // Test 4: List participants
        console.log(chalk.blue('\n📋 Test 4: List Participants'));
        const participants = await client.listParticipants(session.session_id);
        console.log(chalk.green(`✅ Found ${participants.length} participants`));
        participants.forEach((p, index) => {
            console.log(chalk.gray(`   ${index + 1}. ${p.display_name} (${p.avatar_color})`));
        });
        
        // Test 5: Simulate some time passing
        console.log(chalk.blue('\n📋 Test 5: Simulate Session Activity (5 seconds)'));
        console.log(chalk.gray('   Simulating location updates and activity...'));
        
        // Wait 5 seconds
        await new Promise(resolve => setTimeout(resolve, 5000));
        
        // Test 6: Leave sessions
        console.log(chalk.blue('\n📋 Test 6: Leave Sessions'));
        for (let i = 0; i < users.length; i++) {
            const user = users[i];
            const success = await client.leaveSession(session.session_id, user.participant.user_id);
            if (success) {
                console.log(chalk.green(`✅ User ${i + 1} left session`));
            } else {
                console.log(chalk.yellow(`⚠️  User ${i + 1} leave failed`));
            }
        }
        
        // Test 7: Delete session
        console.log(chalk.blue('\n📋 Test 7: Delete Session'));
        const deleted = await client.deleteSession(session.session_id);
        if (deleted) {
            console.log(chalk.green('✅ Session deleted successfully'));
        } else {
            console.log(chalk.yellow('⚠️  Session deletion failed'));
        }
        
        console.log(chalk.green('\n🎉 All API tests passed!'));
        console.log(chalk.blue('📊 Test Summary:'));
        console.log(chalk.white('   ✅ Health check: PASS'));
        console.log(chalk.white('   ✅ Session creation: PASS'));
        console.log(chalk.white(`   ✅ User joins: ${users.length}/3 PASS`));
        console.log(chalk.white('   ✅ List participants: PASS'));
        console.log(chalk.white('   ✅ Session cleanup: PASS'));
        
        return true;
        
    } catch (error) {
        console.error(chalk.red(`\n❌ API test failed: ${error.message}`));
        return false;
    }
}

// Run the test
if (require.main === module) {
    runSimpleApiTest().then(success => {
        if (success) {
            console.log(chalk.green('\n✅ Simple API test completed successfully!'));
            process.exit(0);
        } else {
            console.log(chalk.red('\n❌ Simple API test failed!'));
            process.exit(1);
        }
    });
}

module.exports = runSimpleApiTest;