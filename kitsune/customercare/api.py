import json

from django.http import HttpResponse
from rest_framework import generics, serializers, status
from rest_framework.response import Response
from rest_framework.decorators import api_view
from rest_framework.permissions import DjangoModelPermissions

from kitsune.access.decorators import permission_required
from kitsune.customercare.models import TwitterAccount
from kitsune.sumo.api import GenericAPIException


class TwitterAccountBanPermission(DjangoModelPermissions):
    perms_map = {
        'GET': ['customercare.ban_account'],
    }


class TwitterAccountIgnorePermission(DjangoModelPermissions):
    perms_map = {
        'GET': ['customercare.ignore_account'],
    }


class TwitterAccountSerializer(serializers.ModelSerializer):
    """Serializer for the TwitterAccount model."""
    class Meta:
        model = TwitterAccount


class BannedList(generics.ListAPIView):
    """Get all banned users."""
    queryset = TwitterAccount.uncached.filter(banned=True)
    serializer_class = TwitterAccountSerializer
    permission_classes = (TwitterAccountBanPermission,)


class IgnoredList(generics.ListAPIView):
    """Get all banned users."""
    queryset = TwitterAccount.uncached.filter(ignored=True)
    serializer_class = TwitterAccountSerializer
    permission_classes = (TwitterAccountIgnorePermission,)


@permission_required('customercare.ban_account')
@api_view(['POST'])
def ban(request):
    """Bans a twitter account from using the AoA tool."""
    username = json.loads(request.body).get('username')
    if not username:
        raise GenericAPIException(status.HTTP_400_BAD_REQUEST,
                                  'Username not provided.')

    username = username[1:] if username.startswith('@') else username
    account, created = TwitterAccount.uncached.get_or_create(
        username=username,
        defaults={'banned': True}
    )
    if not created and account.banned:
        raise GenericAPIException(
            status.HTTP_409_CONFLICT,
            'This account is already banned!'
        )
    else:
        account.banned = True
        account.save()

    return Response({'success': 'Account banned successfully!'})


@permission_required('customercare.ban_account')
@api_view(['POST'])
def unban(request):
    """Unbans a twitter account from using the AoA tool."""
    usernames = json.loads(request.body).get('usernames')
    if not usernames:
        raise GenericAPIException(status.HTTP_400_BAD_REQUEST,
                                  'Usernames not provided.')

    accounts = TwitterAccount.uncached.filter(username__in=usernames)
    for account in accounts:
        if account and account.banned:
            account.banned = False
            account.save()

    message = {'success': '{0} users unbanned successfully.'
               .format(len(accounts))}
    return Response(message)


@permission_required('customercare.ignore_account')
def ignore(request):
    """Ignores a twitter account from showing up in the AoA tool."""
    if request.method != 'POST':
        resp = json.dumps({'error': 'Not a POST request!'})
        return HttpResponse(resp, content_type='application/json')

    username = json.loads(request.body).get('username')
    if not username:
        raise GenericAPIException(status.HTTP_400_BAD_REQUEST,
                                  'Username not provided.')

    username = username[1:] if username.startswith('@') else username
    account, created = TwitterAccount.uncached.get_or_create(
        username=username,
        defaults={'ignored': True}
    )
    if not created and account.ignored:
        raise GenericAPIException(
            status.HTTP_409_CONFLICT,
            'This account is already in the ignore list!'
        )
    else:
        account.ignored = True
        account.save()

    resp = json.dumps({'success': 'Account is now being ignored!'})
    return HttpResponse(resp, content_type='application/json')


@permission_required('customercare.ignore_account')
@api_view(['POST'])
def unignore(request):
    """Unignores a twitter account from showing up in the AoA tool."""
    usernames = json.loads(request.body).get('usernames')
    if not usernames:
        raise GenericAPIException(status.HTTP_400_BAD_REQUEST,
                                  'Usernames not provided.')

    accounts = TwitterAccount.uncached.filter(username__in=usernames)
    for account in accounts:
        if account and account.ignored:
            account.ignored = False
            account.save()

    message = {'success': '{0} users unignored successfully.'
               .format(len(accounts))}
    return Response(message)
